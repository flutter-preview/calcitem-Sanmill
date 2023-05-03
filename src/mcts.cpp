// This file is part of Sanmill.
// Copyright (C) 2019-2023 The Sanmill developers (see AUTHORS file)
//
// Sanmill is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Sanmill is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

#include <algorithm>
#include <chrono>
#include <cmath>
#include <iomanip>
#include <iostream>
#include <mutex>
#include <stack>
#include <thread>
#include <vector>

#include "mcts.h"
#include "movepick.h"
#include "option.h"
#include "position.h"
#include "search.h"
#include "types.h"
#include "uci.h"

Value MTDF(Position *pos, Sanmill::Stack<Position> &ss, Value firstguess,
           Depth depth, Depth originDepth, Move &bestMove);

Value qsearch(Position *pos, Sanmill::Stack<Position> &ss, Depth depth,
              Depth originDepth, Value alpha, Value beta, Move &bestMove);

using namespace std;

class ThreadSafeNodeVisits
{
public:
    explicit ThreadSafeNodeVisits(size_t initial_size)
        : node_visits_(initial_size, 0)
        , node_wins_(initial_size, 0)
    { }

    void increment_visits(int move_index, uint32_t visits)
    {
        std::unique_lock<std::mutex> lock(mutex_);
        node_visits_[move_index] += visits;
    }

    void increment_wins(int move_index, uint32_t wins)
    {
        std::unique_lock<std::mutex> lock(mutex_);
        node_wins_[move_index] += wins;
    }

    uint32_t visits(int move_index)
    {
        std::unique_lock<std::mutex> lock(mutex_);
        return node_visits_[move_index];
    }

    uint32_t wins(int move_index)
    {
        std::unique_lock<std::mutex> lock(mutex_);
        return node_wins_[move_index];
    }

private:
    std::vector<uint32_t> node_visits_;
    std::vector<uint32_t> node_wins_;
    std::mutex mutex_;
};

// Class representing a node in the Monte Carlo Tree Search
class Node
{
public:
    Node(Position *position, Move move, Node *parent, int index)
        : position(position)
        , move(move)
        , move_index(index)
        , parent(parent)
    { }

    double win_score() const
    {
        if (num_visits == 0)
            return 0;
        return static_cast<double>(num_wins) / num_visits;
    }

    void increment_visits() { ++num_visits; }

    void increment_wins() { ++num_wins; }

    void add_child(Node *child) { children.emplace_back(child); }

    Position *position {nullptr};
    Move move;
    Node *parent {nullptr};
    std::vector<Node *> children;
    uint32_t num_visits {0};
    uint32_t num_wins {0};
    int move_index {0};
};

// Recursively delete tree starting from the given node
void delete_tree(Node *root)
{
    std::stack<Node *> nodes;
    nodes.push(root);

    while (!nodes.empty()) {
        Node *node = nodes.top();
        nodes.pop();

        for (Node *child : node->children) {
            nodes.push(child);
        }

        delete node->position;
        delete node;
    }
}

// Compute the UCT (Upper Confidence Bound for Trees) value tuned for a node
double uct_value_tuned(const Node *node, double exploration_parameter)
{
    if (node->num_visits == 0) {
        return std::numeric_limits<double>::max();
    }

    double mean = node->win_score();
    double exploration_term = exploration_parameter *
                              std::sqrt(2 * std::log(node->parent->num_visits) /
                                        node->num_visits);
    double variance_term = std::sqrt((mean * (1 - mean)) / node->num_visits);
    double bias_term = BIAS_FACTOR *
                       static_cast<double>(MAX_MOVES - node->move_index);

    return mean + exploration_term + variance_term + bias_term;
}

// Return the best child node according to UCT value tuned
Node *best_uct_child_tuned(Node *node, double exploration_parameter)
{
    Node *best_child = nullptr;
    double best_value = std::numeric_limits<double>::lowest();

    // Loop through all child nodes and find the one with the highest UCT value
    for (Node *child : node->children) {
        double value = uct_value_tuned(child, exploration_parameter);
        if (value > best_value) {
            best_value = value;
            best_child = child;
        }
    }

    return best_child;
}

// Select the next node to expand
Node *select(Node *node, double exploration_parameter)
{
    while (!node->children.empty()) {
        node = best_uct_child_tuned(node, exploration_parameter);
    }
    return node;
}

// Expand the current node by adding child nodes for all legal moves
Node *expand(Node *node)
{
    Position *pos = node->position;

    MovePicker mp(*pos);
    mp.next_move(); // Sort moves
    // const int moveCount = std::max(mp.move_count() / SEARCH_PRUNING_FACTOR,
    // 1);
    const int moveCount = mp.move_count();

    // Add child nodes for each sorted legal move
    for (int i = 0; i < moveCount; i++) {
        Position *child_position = new Position(*pos);
        const Move move = mp.moves[i].move;
        child_position->do_move(move);

        Node *child = new Node(child_position, move, node, i);
        node->add_child(child);
    }

    return node->children.empty() ? node : node->children.front();
}

// Simulate a game from the given node and return whether it resulted in a win
bool simulate(Node *node, Sanmill::Stack<Position> &ss)
{
    Position *pos = node->position;

    Move bestMove {MOVE_NONE};

    Value value = qsearch(pos, ss, ALPHA_BETA_DEPTH, ALPHA_BETA_DEPTH,
                          -VALUE_INFINITE, VALUE_INFINITE, bestMove);

    return value > 0;
}

// Back propagate the results of the simulation up the tree
void backpropagate(Node *node, bool win)
{
    while (node != nullptr) {
        node->increment_visits();
        if (win)
            node->increment_wins();
        win = !win;
        node = node->parent;
    }
}

#ifdef MCTS_PRINT_STAT
void print_stats(const MovePicker &mp, ThreadSafeNodeVisits &shared_visits,
                 Move bestMove, Value best_value, double win_score)
{
    uint32_t total_visits = 0;

    // Iterate through all moves and print their statistics
    std::cout << "\n";
    std::cout << std::setw(5) << "Move" << "    " << std::setw(9) << std::fixed << std::setprecision(6)
              << "Win Rate"
              << "    " << std::setw(6) << "Wins"
              << "    " << std::setw(6) << "Visits"
              << '\n';
    std::cout << "----------------------------------------\n";
    for (int i = 0; i < mp.move_count(); ++i) {
        uint32_t visits = shared_visits.visits(i);
        total_visits += visits;
        uint32_t wins = shared_visits.wins(i);
        double win_rate = static_cast<double>(wins) / visits;

        std::string move_str = UCI::move(mp.moves[i].move);

        std::cout << std::setw(5) << move_str << "    " << std::setw(9)
                  << std::fixed << std::setprecision(6) << win_rate << "    "
                  << std::setw(6) << wins << "    " << std::setw(6) << visits
                  << '\n';
    }
    std::cout << "----------------------------------------\n";
    std::cout << "Best Move: " << UCI::move(bestMove) << '\n';
    std::cout << "Best Move Win Score: " << std::fixed << std::setprecision(6)
              << win_score << "\n";
    std::cout << "Best Move Value: " << (int)best_value << '\n';

    std::cout << "-----------------------------\n";
    std::cout << "Total visits: " << total_visits << '\n';
    std::cout << "\n";
}
#endif // MCTS_PRINT_STAT

void mcts_worker(Position *pos, int max_iterations,
                 ThreadSafeNodeVisits &shared_visits)
{
    Sanmill::Stack<Position> ss;

    Node *root = new Node(new Position(*pos), MOVE_NONE, nullptr, 0);

    int iteration = 0;
    const int check_time_mask = CHECK_TIME_FREQUENCY - 1;

    // Add time limit (no limit if gameOptions.getMoveTime() returns 0)
    const auto start_time = std::chrono::steady_clock::now();
    const auto move_time = gameOptions.getMoveTime();
    const auto time_limit = move_time > 0 ?
                                std::chrono::seconds(move_time) :
                                std::chrono::steady_clock::time_point::max() -
                                    std::chrono::steady_clock::now();

    while (iteration < max_iterations) {
        Node *node = select(root, EXPLORATION_PARAMETER);
        Node *expanded_node = expand(node);
        bool win = simulate(expanded_node, ss);
        backpropagate(expanded_node, win);

        iteration++;

        if ((iteration & check_time_mask) == 0) {
            auto current_time = std::chrono::steady_clock::now();
            if (move_time > 0 && current_time - start_time >= time_limit) {
                break;
            }
        }
    }

    for (Node *child : root->children) {
        shared_visits.increment_visits(child->move_index, child->num_visits);
        shared_visits.increment_wins(child->move_index, child->num_wins);
    }

    delete_tree(root);
}

// Perform Monte Carlo Tree Search to find the best move and its value
Value monte_carlo_tree_search(Position *pos, Move &bestMove)
{
    // Adjust these values according to your needs
    int max_iterations = gameOptions.getSkillLevel() *
                         ITERATIONS_PER_SKILL_LEVEL;

    // WAR fix: The first move is slow.
    if (pos->is_board_empty()) {
        max_iterations = 1;
    }

    ThreadSafeNodeVisits shared_visits(MAX_MOVES);

    int num_threads = std::thread::hardware_concurrency();
    if (num_threads == 0) {
        num_threads = 1;
    }
    std::vector<std::thread> threads(num_threads);

    for (int i = 0; i < num_threads; ++i) {
        threads[i] = std::thread(mcts_worker, pos, max_iterations / num_threads,
                                 std::ref(shared_visits));
    }

    for (auto &t : threads) {
        if (t.joinable()) {
            t.join();
        }
    }

    MovePicker mp(*pos);
    mp.next_move();

    int best_move_index = 0;
    uint32_t max_visits = 0;

    for (int i = 0; i < mp.move_count(); ++i) {
        uint32_t visits = shared_visits.visits(i);
        if (visits > max_visits) {
            max_visits = visits;
            best_move_index = i;
        }
    }

    bestMove = mp.moves[best_move_index].move;

    double win_score = static_cast<double>(max_visits) /
                       (max_iterations / num_threads);
    Value best_value = static_cast<Value>(win_score * 2.0 - 1.0);

#ifdef MCTS_PRINT_STAT
    print_stats(mp, shared_visits, bestMove, best_value, win_score);
#endif // MCTS_PRINT_STAT

    return best_value;
}
