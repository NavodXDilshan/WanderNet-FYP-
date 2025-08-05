from flask import Flask, request, jsonify
from flask_cors import CORS
from pymongo.mongo_client import MongoClient
from pymongo.server_api import ServerApi
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
import numpy as np
from bson import json_util
import json
import math
from datetime import datetime, timedelta
from collections import defaultdict, Counter
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity
import re

app = Flask(__name__)
CORS(app)

uri = "mongodb+srv://kmnavoddilshan:NJj9WAAEjavgxBgK@cluster0.vighfql.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0"

client = MongoClient(uri, server_api=ServerApi('1'))
db = client.get_database('posts')

try:
    client.admin.command('ping')
    print("Pinged your deployment. You successfully connected to MongoDB!")
except Exception as e:
    print(e)


class RecommendationEngine:
    def __init__(self, db):
        self.db = db
        self.posts_collection = db.get_collection('posts')

    def calculate_distance(self, lat1, lon1, lat2, lon2):
        """Calculate distance between two points using Haversine formula"""
        if not all([lat1, lon1, lat2, lon2]):
            return float('inf')

        R = 6371  # Earth's radius in kilometers

        lat1_rad = math.radians(lat1)
        lon1_rad = math.radians(lon1)
        lat2_rad = math.radians(lat2)
        lon2_rad = math.radians(lon2)

        dlat = lat2_rad - lat1_rad
        dlon = lon2_rad - lon1_rad

        a = math.sin(dlat / 2) ** 2 + math.cos(lat1_rad) * math.cos(lat2_rad) * math.sin(dlon / 2) ** 2
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))

        return R * c

    def get_user_profile(self, username):
        """Build comprehensive user profile from interaction history"""
        # Get posts user has liked
        liked_posts = list(self.posts_collection.find({
            'likedBy': username,
            'valid': 'true'
        }))

        # Get posts user has commented on
        commented_posts = list(self.posts_collection.find({
            'commentsList.userName': username,
            'valid': 'true'
        }))

        # Get user's own posts
        user_posts = list(self.posts_collection.find({
            'userName': username,
            'valid': 'true'
        }))

        # Extract preferred locations
        all_user_locations = []
        for post in liked_posts + commented_posts + user_posts:
            if post.get('latitude') and post.get('longitude'):
                all_user_locations.append({
                    'lat': post['latitude'],
                    'lng': post['longitude'],
                    'location': post.get('location', '')
                })

        # Extract content preferences
        all_content = [post.get('content', '') for post in liked_posts + commented_posts]
        content_keywords = self._extract_keywords(' '.join(all_content))

        # Calculate engagement patterns
        avg_likes_given = len(liked_posts)
        avg_comments_given = len(commented_posts)

        return {
            'username': username,
            'liked_posts': liked_posts,
            'commented_posts': commented_posts,
            'user_posts': user_posts,
            'preferred_locations': all_user_locations,
            'content_keywords': content_keywords,
            'engagement_score': avg_likes_given + (avg_comments_given * 2),
            'total_interactions': len(liked_posts) + len(commented_posts)
        }

    def _extract_keywords(self, text):
        """Extract important keywords from text"""
        if not text:
            return []


        words = re.findall(r'\b[a-zA-Z]{3,}\b', text.lower())
        # Remove common stop words
        stop_words = {'the', 'and', 'for', 'are', 'but', 'not', 'you', 'all', 'can', 'had', 'her', 'was', 'one', 'our',
                      'out', 'day', 'get', 'has', 'him', 'his', 'how', 'may', 'new', 'now', 'old', 'see', 'two', 'who',
                      'boy', 'did', 'its', 'let', 'put', 'say', 'she', 'too', 'use'}
        keywords = [word for word in words if word not in stop_words]
        return list(Counter(keywords).keys())[:10]  # Top 10 keywords

    def calculate_location_score(self, user_profile, post):
        """Calculate location-based similarity score (0-1)"""
        if not user_profile['preferred_locations'] or not post.get('latitude') or not post.get('longitude'):
            return 0.5  # Neutral score if no location data

        post_lat = post['latitude']
        post_lng = post['longitude']

        min_distance = float('inf')
        for pref_loc in user_profile['preferred_locations']:
            distance = self.calculate_distance(
                post_lat, post_lng,
                pref_loc['lat'], pref_loc['lng']
            )
            min_distance = min(min_distance, distance)

        # Convert distance to score (closer = higher score)
        # Assume 100km is the maximum relevant distance
        if min_distance == float('inf'):
            return 0.5

        max_distance = 100  # km
        score = max(0, 1 - (min_distance / max_distance))
        return score

    def calculate_content_similarity_score(self, user_profile, post):
        """Calculate content similarity score using keyword matching (0-1)"""
        if not user_profile['content_keywords'] or not post.get('content'):
            return 0.5

        post_keywords = self._extract_keywords(post['content'])

        if not post_keywords:
            return 0.5

        # Calculate Jaccard similarity
        user_keywords_set = set(user_profile['content_keywords'])
        post_keywords_set = set(post_keywords)

        intersection = len(user_keywords_set.intersection(post_keywords_set))
        union = len(user_keywords_set.union(post_keywords_set))

        if union == 0:
            return 0.5

        jaccard_score = intersection / union
        return jaccard_score

    def calculate_social_proof_score(self, post):
        """Calculate social engagement score (0-1)"""
        likes = post.get('likes', 0)
        comments = post.get('comments', 0)
        shares = post.get('shares', 0)


        engagement = likes + (comments * 2) + (shares * 3)


        normalized_score = 1 / (1 + math.exp(-(engagement - 10) / 5))
        return normalized_score

    def calculate_temporal_score(self, post):
        """Calculate recency score (0-1)"""
        try:
            post_time = datetime.fromisoformat(post['createdAt'].replace('Z', '+00:00'))
            current_time = datetime.now(post_time.tzinfo)

            time_diff = (current_time - post_time).total_seconds()
            hours_diff = time_diff / 3600

            # Recent posts get higher scores
            # Score decreases exponentially with time
            # Half-life of 24 hours
            score = math.exp(-hours_diff / 24)
            return min(score, 1.0)

        except (ValueError, KeyError):
            return 0.5  # Neutral score if date parsing fails

    def calculate_user_similarity_score(self, user_profile, post):
        """Calculate similarity with post author (0-1)"""
        post_author = post.get('userName', '')

        if post_author == user_profile['username']:
            return 0  # Don't recommend user's own posts

        interacted_authors = set()
        for liked_post in user_profile['liked_posts']:
            interacted_authors.add(liked_post.get('userName', ''))
        for commented_post in user_profile['commented_posts']:
            interacted_authors.add(commented_post.get('userName', ''))

        if post_author in interacted_authors:
            return 0.8  # High score for familiar authors

        return 0.4

    def calculate_diversity_penalty(self, post, recent_recommendations):
        """Calculate penalty for content that's too similar to recent recommendations"""
        if not recent_recommendations:
            return 0

        post_location = post.get('location', '').lower()
        recent_locations = [r.get('location', '').lower() for r in recent_recommendations]
        location_matches = sum(1 for loc in recent_locations if loc and post_location and loc in post_location)

        post_keywords = set(self._extract_keywords(post.get('content', '')))
        recent_keywords = set()
        for rec in recent_recommendations:
            recent_keywords.update(self._extract_keywords(rec.get('content', '')))

        keyword_overlap = len(post_keywords.intersection(recent_keywords)) / max(len(post_keywords), 1)

        diversity_penalty = min((location_matches * 0.3) + (keyword_overlap * 0.7), 1.0)
        return diversity_penalty

    def calculate_multi_factor_score(self, user_profile, post, weights, recent_recommendations=None):
        """Calculate comprehensive recommendation score"""
        if recent_recommendations is None:
            recent_recommendations = []

        
        location_score = self.calculate_location_score(user_profile, post)
        content_score = self.calculate_content_similarity_score(user_profile, post)
        social_score = self.calculate_social_proof_score(post)
        temporal_score = self.calculate_temporal_score(post)
        user_similarity_score = self.calculate_user_similarity_score(user_profile, post)
        diversity_penalty = self.calculate_diversity_penalty(post, recent_recommendations)

        
        base_score = (
                weights['location'] * location_score +
                weights['content'] * content_score +
                weights['social'] * social_score +
                weights['temporal'] * temporal_score +
                weights['user_similarity'] * user_similarity_score
        )

       
        final_score = base_score * (1 - diversity_penalty * weights['diversity_penalty'])

        return {
            'total_score': final_score,
            'breakdown': {
                'location_score': location_score,
                'content_score': content_score,
                'social_score': social_score,
                'temporal_score': temporal_score,
                'user_similarity_score': user_similarity_score,
                'diversity_penalty': diversity_penalty,
                'base_score': base_score
            }
        }

    def get_personalized_recommendations(self, username, limit=10, weights=None):
        """Generate personalized recommendations using multi-factor scoring"""

        
        if weights is None:
            weights = {
                'location': 0.25,
                'content': 0.30,
                'social': 0.20,
                'temporal': 0.15,
                'user_similarity': 0.10,
                'diversity_penalty': 0.3
            }

        
        user_profile = self.get_user_profile(username)

        
        interacted_post_ids = set()
        for post in user_profile['liked_posts'] + user_profile['commented_posts'] + user_profile['user_posts']:
            interacted_post_ids.add(str(post['_id']))

        candidate_posts = list(self.posts_collection.find({
            'valid': 'true',
            '_id': {'$nin': [post['_id'] for post in user_profile['user_posts']]},
            'userName': {'$ne': username}
        }))

        
        candidate_posts = [post for post in candidate_posts if str(post['_id']) not in interacted_post_ids]

        
        scored_posts = []
        for post in candidate_posts:
            score_data = self.calculate_multi_factor_score(user_profile, post, weights)
            scored_posts.append({
                'post': post,
                'score': score_data['total_score'],
                'score_breakdown': score_data['breakdown']
            })

        
        scored_posts.sort(key=lambda x: x['score'], reverse=True)

        
        final_recommendations = []
        recent_recommendations = []

        for scored_post in scored_posts:
            if len(final_recommendations) >= limit:
                break

            post = scored_post['post']

            
            updated_score_data = self.calculate_multi_factor_score(
                user_profile, post, weights, recent_recommendations
            )

            final_recommendations.append({
                'post': post,
                'score': updated_score_data['total_score'],
                'score_breakdown': updated_score_data['breakdown'],
                'explanation': self._generate_explanation(updated_score_data['breakdown'], post)
            })

            recent_recommendations.append(post)

        return final_recommendations, user_profile

    def _generate_explanation(self, score_breakdown, post):
        """Generate human-readable explanation for recommendation"""
        explanations = []

        if score_breakdown['location_score'] > 0.7:
            explanations.append(f"Similar to locations you've visited ({post.get('location', 'Unknown location')})")

        if score_breakdown['content_score'] > 0.6:
            explanations.append("Matches your content interests")

        if score_breakdown['social_score'] > 0.7:
            explanations.append("Popular among other users")

        if score_breakdown['temporal_score'] > 0.8:
            explanations.append("Recent post")

        if score_breakdown['user_similarity_score'] > 0.7:
            explanations.append("From users you've interacted with before")

        if not explanations:
            explanations.append("Recommended based on your activity patterns")

        return "; ".join(explanations)



recommendation_engine = None


def init_recommendation_engine(db):
    global recommendation_engine
    recommendation_engine = RecommendationEngine(db)


# Get all posts
@app.route('/posts', methods=['GET'])
def get_posts():
    try:
        
        posts = list(db.get_collection('posts').find())

        
        posts_json = json.loads(json_util.dumps(posts))

        return jsonify({
            'status': 'success',
            'data': posts_json,
            'count': len(posts)
        }), 200

    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500


@app.route('/posts/recommendations', methods=['GET'])
def get_user_recommendations():
    """Enhanced recommendation endpoint with multi-factor scoring"""
    username = request.args.get('username')
    limit = int(request.args.get('limit', 10))
    include_explanation = request.args.get('explain', 'false').lower() == 'true'

    
    custom_weights = {}
    weight_params = ['location', 'content', 'social', 'temporal', 'user_similarity', 'diversity_penalty']
    for param in weight_params:
        if request.args.get(f'weight_{param}'):
            try:
                custom_weights[param] = float(request.args.get(f'weight_{param}'))
            except ValueError:
                pass

    if not username:
        return jsonify({
            'status': 'error',
            'message': 'Username is required'
        }), 400

    try:
        print(f"Generating recommendations for user: {username}")

        
        recommendations, user_profile = recommendation_engine.get_personalized_recommendations(
            username=username.strip('"').strip("'"),
            limit=limit,
            weights=custom_weights if custom_weights else None
        )

        
        formatted_recommendations = []
        for rec in recommendations:
            post_data = json.loads(json_util.dumps(rec['post']))

            recommendation_item = {
                **post_data,
                'recommendation_score': round(rec['score'], 3)
            }

            if include_explanation:
                recommendation_item.update({
                    'explanation': rec['explanation'],
                    'score_breakdown': {
                        k: round(v, 3) for k, v in rec['score_breakdown'].items()
                    }
                })

            formatted_recommendations.append(recommendation_item)

        response_data = {
            'status': 'success',
            'data': formatted_recommendations,
            'count': len(formatted_recommendations),
            'user_profile_summary': {
                'total_interactions': user_profile['total_interactions'],
                'preferred_locations_count': len(user_profile['preferred_locations']),
                'engagement_score': user_profile['engagement_score']
            }
        }

        return jsonify(response_data), 200

    except Exception as e:
        print(f"Error generating recommendations: {str(e)}")
        return jsonify({
            'status': 'error',
            'message': f'Failed to generate recommendations: {str(e)}'
        }), 500



@app.route('/posts/commented', methods=['GET'])
def get_user_commented_posts():
    username = request.args.get('username')
    if not username:
        return jsonify({
            'status': 'error',
            'message': 'Username is required'
        }), 400

    try:
        print(f"Fetching commented posts for user: {username}")
        posts = list(db.get_collection('posts').find({
            'commentsList.userName': username.strip('"').strip("'"),
            'valid': 'true'
        }))

        posts_json = json.loads(json_util.dumps(posts))
        return posts_json, 200, {'Content-Type': 'application/json'}

    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500



@app.route('/locations/commented', methods=['GET'])
def get_user_commented_locations():
    username = request.args.get('username')
    if not username:
        return jsonify({
            'status': 'error',
            'message': 'Username is required'
        }), 400

    try:
        print(f"Fetching locations for user: {username}")
        
        posts = list(db.get_collection('posts').find({
            'commentsList.userName': username.strip('"').strip("'"),
            'valid': 'true'
        }))

        
        locations_dict = {}
        for post in posts:
            if 'location' in post and post['location'] and post['location'] != "Location selected":
                location_key = post['location']
               
                if location_key not in locations_dict:
                    location_obj = {
                        'location': post['location'],
                        'latitude': post.get('latitude'),
                        'longitude': post.get('longitude')
                    }
                   
                    if location_obj['latitude'] is not None and location_obj['longitude'] is not None:
                        locations_dict[location_key] = location_obj

       
        locations_list = list(locations_dict.values())

        return locations_list, 200
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)