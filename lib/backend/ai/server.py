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

app = Flask(__name__)
CORS(app)


uri = "mongodb+srv://kmnavoddilshan:NJj9WAAEjavgxBgK@cluster0.vighfql.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0"
# Create a new client and connect to the server
client = MongoClient(uri, server_api=ServerApi('1'))
db = client.get_database('posts')
# Send a ping to confirm a successful connection
try:
    client.admin.command('ping')
    print("Pinged your deployment. You successfully connected to MongoDB!")
except Exception as e:
    print(e)

# Get all posts
@app.route('/posts', methods=['GET'])
def get_posts():
    try:
        # Get all posts from collection
        posts = list(db.get_collection('posts').find())
        
        # Convert MongoDB cursor to JSON serializable format
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
    
# Get posts a user commented on
@app.route('/posts/commented', methods=['GET'])
def get_user_commented_posts():
    username = request.args.get('username')
    if not username:
        return jsonify({
            'status': 'error',
            'message': 'Username is required'
        }), 400
    
    try:
        print(f"Fetching posts for user: {username}")
        # Find posts where the user has commented
        posts = list(db.get_collection('posts').find({'commentsList.userName': username.strip('"').strip("'")}))
        
        # Convert MongoDB cursor to JSON serializable format
        posts_json = json.loads(json_util.dumps(posts))
        
        # return jsonify({
        #     'status': 'success',
        #     'data': posts_json,
        #     'count': len(posts)
        # }), 200

        return posts_json, 200, {'Content-Type': 'application/json'}
    
    except Exception as e:
        return jsonify({
            'status': 'error',
            'message': str(e)
        }), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)