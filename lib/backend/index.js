const express = require('express');
const { MongoClient, ObjectId } = require('mongodb');
const cors = require('cors');
const dotenv = require('dotenv');

dotenv.config();

const app = express();
const port = process.env.PORT || 3000;
const uri = process.env.MONGODB_URI;

app.use(cors());
app.use(express.json());

const client = new MongoClient(uri);

async function connectToMongoDB() {
  try {
    await client.connect();
    console.log('Connected to MongoDB');
  } catch (error) {
    console.error('MongoDB connection error:', error);
  }
}

connectToMongoDB();

// GET /posts - Fetch all posts for general feed
app.get('/posts', async (req, res) => {
  try {
    const database = client.db('posts_db');
    const posts = database.collection('posts');
    const postList = await posts
      .find({})
      .sort({ createdAt: -1 }) // Sort by newest first
      .limit(20) // Optional: Limit for performance
      .toArray();
    res.json(postList);
  } catch (error) {
    console.error('Error fetching posts:', error);
    res.status(500).json({ error: 'Failed to fetch posts' });
  }
});

// GET /posts/:email - Fetch posts by a specific user
app.get('/posts/:email', async (req, res) => {
  try {
    const database = client.db('posts_db');
    const email = req.params.email;
    const posts = database.collection(email);
    const postList = await posts
      .find({})
      .sort({ createdAt: -1 })
      .limit(20)
      .toArray();
    res.json(postList);
  } catch (error) {
    console.error('Error fetching user posts:', error);
    res.status(500).json({ error: 'Failed to fetch user posts' });
  }
});

// POST /posts/:email - Create a new post
app.post('/posts/:email', async (req, res) => {
  try {
    const database = client.db('posts_db');
    const email = req.params.email;
    const newPost = {
      ...req.body,
      createdAt: new Date().toISOString(),
    };

    // Save to user's email-based collection
    const userPosts = database.collection(email);
    const userResult = await userPosts.insertOne(newPost);

    // Save to general posts collection
    const generalPosts = database.collection('posts');
    await generalPosts.insertOne({
      ...newPost,
      userEmail: email,
    });

    res.status(201).json({ _id: userResult.insertedId });
  } catch (error) {
    console.error('Error creating post:', error);
    res.status(500).json({ error: 'Failed to create post' });
  }
});

// PATCH /posts/:id/like - Increment likes for a post
app.patch('/posts/:email/:id/like', async (req, res) => {
  try {
    const database = client.db('posts_db');
    const email = req.params.email;
    const postId = req.params.id;

    // Update user's email-based collection
    const userPosts = database.collection(email);
    const userResult = await userPosts.updateOne(
      { _id: new ObjectId(postId) },
      { $inc: { likes: 1 } }
    );

    // Update general posts collection
    const generalPosts = database.collection('posts');
    await generalPosts.updateOne(
      { _id: new ObjectId(postId), userEmail: email },
      { $inc: { likes: 1 } }
    );

    res.json(userResult);
  } catch (error) {
    console.error('Error liking post:', error);
    res.status(500).json({ error: 'Failed to update like' });
  }
});

app.listen(port, () => {
  console.log(`Posts Service running on http://localhost:${port}`);
});