# backend/main.py
import heapq
import uvicorn
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Dict, Optional
import requests
from dotenv import load_dotenv

load_dotenv()   
import os

app = FastAPI()

# Pydantic model for request data
class Location(BaseModel):
    lat: float
    lng: float

class RouteRequest(BaseModel):
    locations: List[Location]
    start: int
    target: int
    time_limit: float
    switch_weights: Optional[List[float]] = None
    scores: Optional[List[float]] = None
    algorithm: str = "max_nodes"  # Default to max_nodes, options: "max_nodes", "max_score", "hybrid"

# Dijkstra's algorithm
def dijkstra_shortest_time_to_t(locations: List[Location], t: int, time_matrix: List[List[float]], switch_weights: List[float] = None) -> Dict[int, float]:
    V = len(locations)
    if switch_weights is None:
        switch_weights = [0.0] * V

    distances = {v: float('inf') for v in range(V)}
    distances[t] = 0.0
    pq = [(0.0, t)]
    visited = set()

    while pq:
        current_distance, u = heapq.heappop(pq)
        if u in visited:
            continue
        visited.add(u)
        for v in range(V):
            if v in visited:
                continue
            edge_cost = time_matrix[u][v] + switch_weights[v]
            if current_distance + edge_cost < distances[v]:
                distances[v] = current_distance + edge_cost
                heapq.heappush(pq, (distances[v], v))

    return distances

# MaxNodesRoute algorithm
def max_nodes_route(locations: List[Location], s: int, t: int, T: float, time_matrix: List[List[float]], switch_weights: List[float] = None) -> List[int]:
    V = len(locations)
    if switch_weights is None:
        switch_weights = [0.0] * V

    shortest_time_to_t = dijkstra_shortest_time_to_t(locations, t, time_matrix, switch_weights)

    total_travel_time = sum(sum(row[i] for i in range(V) if i != j) for j, row in enumerate(time_matrix)) / (V * (V - 1))
    avg_switch = sum(w for i, w in enumerate(switch_weights) if i != s and i != t) / (V - 2) if V > 2 else 0
    avg_travel_time = total_travel_time + avg_switch

    alpha = 0.5
    pq = [(0, (s, 0.0, 0, [s]))]  # (priority, (node, total_time, node_count, path))
    best_node_count = float('-inf')
    best_path = None

    while pq:
        _, (u, total_time, node_count, path) = heapq.heappop(pq)

        if u == t and total_time <= T:
            if node_count > best_node_count:
                best_node_count = node_count
                best_path = path
            continue

        if total_time + shortest_time_to_t[u] > T:
            continue

        for v in range(V):
            if v in path:
                continue
            new_time = total_time + time_matrix[u][v] + switch_weights[v]
            if new_time + shortest_time_to_t[v] <= T:
                new_node_count = node_count + 1
                new_path = path + [v]
                est_nodes = (T - new_time - shortest_time_to_t[v]) / avg_travel_time if avg_travel_time > 0 else 0
                score = new_node_count / new_time + alpha * est_nodes if new_time > 0 else float('inf')
                heapq.heappush(pq, (-score, (v, new_time, new_node_count, new_path)))

    return best_path if best_path is not None else []

# MaxScoreRoute algorithm
def max_score_route(locations: List[Location], s: int, t: int, T: float, time_matrix: List[List[float]], switch_weights: List[float] = None, scores: List[float] = None) -> List[int]:
    V = len(locations)
    if switch_weights is None:
        switch_weights = [0.0] * V
    if scores is None:
        scores = [1.0] * V  # Default score of 1 for each location

    shortest_time_to_t = dijkstra_shortest_time_to_t(locations, t, time_matrix, switch_weights)

    total_travel_time = sum(sum(row[i] for i in range(V) if i != j) for j, row in enumerate(time_matrix)) / (
                V * (V - 1))
    avg_switch = sum(w for i, w in enumerate(switch_weights) if i != s and i != t and w < 300) / len([w for i, w in enumerate(switch_weights) if i != s and i != t and w < 300]) if any(i != s and i != t for i in range(V)) else 0
    avg_travel_time = total_travel_time + avg_switch

    alpha = 0.1
    pq = [(0, (s, 0.0, 0.0, [s]))]  # (priority, (node, total_time, score, path))
    best_score = float('-inf')
    best_path = None

    while pq:
        _, (u, total_time, score, path) = heapq.heappop(pq)

        if u == t and total_time <= T:
            if score > best_score:
                best_score = score
                best_path = path
            continue

        if total_time + shortest_time_to_t[u] > T:
            continue

        for v in range(V):
            if v in path:
                continue
            new_time = total_time + time_matrix[u][v] + switch_weights[v]
            if new_time + shortest_time_to_t[v] <= T:
                new_score = score + scores[v]
                new_path = path + [v]
                est_score = (T - new_time - shortest_time_to_t[v]) / avg_travel_time * max(
                    scores) if avg_travel_time > 0 else 0
                priority = new_score + alpha * est_score  # Prioritize score over time
                heapq.heappush(pq, (-priority, (v, new_time, new_score, new_path)))

    return best_path if best_path is not None else []

# HybridRoute algorithm
def hybrid_route(locations: List[Location], s: int, t: int, T: float, time_matrix: List[List[float]],switch_weights: List[float] = None, scores: List[float] = None, beta: float = 0.5) -> List[int]:
    V = len(locations)
    if switch_weights is None:
        switch_weights = [0.0] * V
    if scores is None:
        scores = [1.0] * V

    shortest_time_to_t = dijkstra_shortest_time_to_t(locations, t, time_matrix, switch_weights)

    total_travel_time = sum(sum(row[i] for i in range(V) if i != j) for j, row in enumerate(time_matrix)) / (V * (V - 1))
    avg_switch = sum(w for i, w in enumerate(switch_weights) if i != s and i != t and w < 300) / len([w for i, w in enumerate(switch_weights) if i != s and i != t and w < 300]) if any(i != s and i != t for i in range(V)) else 0
    avg_travel_time = total_travel_time + avg_switch

    alpha = 0.5
    pq = [(0, (s, 0.0, 0, 0.0, [s]))]  # (priority, (node, total_time, node_count, score, path))
    best_hybrid = float('-inf')
    best_path = None

    while pq:
        _, (u, total_time, node_count, score, path) = heapq.heappop(pq)

        if u == t and total_time <= T:
            hybrid_value = beta * node_count + (1 - beta) * score
            if hybrid_value > best_hybrid:
                best_hybrid = hybrid_value
                best_path = path
            continue

        if total_time + shortest_time_to_t[u] > T:
            continue

        for v in range(V):
            if v in path:
                continue
            new_time = total_time + time_matrix[u][v] + switch_weights[v]
            if new_time + shortest_time_to_t[v] <= T:
                new_node_count = node_count + 1
                new_score = score + scores[v]
                new_path = path + [v]
                est_nodes = (T - new_time - shortest_time_to_t[v]) / avg_travel_time if avg_travel_time > 0 else 0
                est_score = est_nodes * max(scores) if avg_travel_time > 0 else 0
                hybrid_est = beta * est_nodes + (1 - beta) * est_score
                priority = (beta * new_node_count + (1 - beta) * new_score) / new_time + alpha * hybrid_est if new_time > 0 else float('inf')
                heapq.heappush(pq, (-priority, (v, new_time, new_node_count, new_score, new_path)))

    return best_path if best_path is not None else []

# API endpoint
@app.post("/optimize_route")
async def optimize_route(request: RouteRequest):
    """
    Optimize a route based on the given locations, time limit, and selected algorithm.

    Args:
        request (RouteRequest): Request containing:
            - locations: List of coordinates (lat, lng).
            - start: Starting location index.
            - target: Target location index.
            - time_limit: Maximum total time in minutes.
            - switch_weights: Optional list of visit times in hours (e.g., time spent at each location).
            - scores: Optional list of location scores (e.g., ratings).
            - algorithm: Optimization algorithm ("max_nodes", "max_score", or "hybrid").

    Returns:
        Dict: Contains the optimized route as a list of indices.
    """
    api_key = os.getenv("GOOGLE_API")  # Replace with your API key
    locations = request.locations
    s = request.start
    t = request.target
    T = request.time_limit
    switch_weights = request.switch_weights
    scores = request.scores
    algorithm = request.algorithm.lower()  # Normalize to lowercase

    V = len(locations)
    if V < 2 or s < 0 or t < 0 or s >= V or t >= V or T <= 0:
        raise HTTPException(status_code=400, detail="Invalid input parameters")

    if algorithm not in ["max_nodes", "max_score", "hybrid"]:
        raise HTTPException(status_code=400, detail="Invalid algorithm. Use 'max_nodes', 'max_score', or 'hybrid'")

    # Convert switch_weights from hours to minutes
    if switch_weights is not None:
        switch_weights = [w * 60 for w in switch_weights]
    else:
        switch_weights = [0.0] * V

    try:
        # Fetch time matrix from Google Maps API
        origins = "|".join([f"{loc.lat},{loc.lng}" for loc in locations])
        url = f"https://maps.googleapis.com/maps/api/distancematrix/json?origins={origins}&destinations={origins}&key={api_key}"
        response = requests.get(url).json()

        if response['status'] != 'OK':
            raise HTTPException(status_code=500, detail="Google Maps API error")

        # Build time matrix
        time_matrix = []
        for row in response['rows']:
            row_times = []
            for element in row['elements']:
                if element['status'] == 'OK':
                    row_times.append(element['duration']['value'] / 60)  # Convert seconds to minutes
                else:
                    row_times.append(float('inf'))
            time_matrix.append(row_times)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to fetch travel times: {str(e)}")

    try:
        # Select and run the appropriate algorithm
        if algorithm == "max_nodes":
            route = max_nodes_route(locations, s, t, T, time_matrix, switch_weights)
        elif algorithm == "max_score":
            route = max_score_route(locations, s, t, T, time_matrix, switch_weights, scores)
        elif algorithm == "hybrid":
            route = hybrid_route(locations, s, t, T, time_matrix, switch_weights, scores)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Route optimization failed: {str(e)}")

    return {"route": route}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)