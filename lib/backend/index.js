const express = require('express');
const { MongoClient, ObjectId } = require('mongodb');
const cors = require('cors');
const dotenv = require('dotenv');
const fetch = (...args) => import('node-fetch').then(({default: fetch}) => fetch(...args)); // Add this dependency

dotenv.config();

const app = express();
const port = process.env.PORT || 3000;
const uri = process.env.MONGODB_URI;
const UPLOADTHING_API_KEY = process.env.UPLOADTHING_API_KEY; // Add to your .env file

app.use(cors());
app.use(express.json());

let client = new MongoClient(uri);

async function connectToMongoDB() {
  try {
    await client.connect();
    console.log('Connected to MongoDB');
        
    // Add connection monitoring
    client.on('close', () => {
      console.log('MongoDB connection closed. Attempting to reconnect...');
      setTimeout(reconnect, 5000); // Try to reconnect after 5 seconds
    });

    client.on('error', (error) => {
      console.error('MongoDB connection error:', error);
      setTimeout(reconnect, 5000);
    });
   
  } catch (error) {
    console.error('MongoDB connection error:', error);
    setTimeout(reconnect, 5000);
  }
}

async function reconnect() {
  try {
    if (client) {
      await client.close(); // Close existing connection
    }
    client = new MongoClient(uri); // Create new client
    await connectToMongoDB();
  } catch (error) {
    console.error('Reconnection failed:', error);
    setTimeout(reconnect, 5000);
  }
}

// Helper function to get database connection
async function getDatabase() {
  if (!client.topology || !client.topology.isConnected()) {
    await reconnect();
  }
  return client.db('posts_db');
}

// Existing routes
app.get('/posts', async (req, res) => {
  try {
    const database = await getDatabase();
    const posts = database.collection('posts');
    const postList = await posts
      .find({})
      .sort({ createdAt: -1 })
      .limit(20)
      .toArray();
    res.json(postList);
  } catch (error) {
    console.error('Error fetching posts:', error);
    res.status(500).json({ error: 'Failed to fetch posts' });
  }
});

// NEW: UploadThing integration routes
app.post('/api/prepare-upload', async (req, res) => {
  const { files, callbackUrl, callbackSlug, routConfig, metadata } = req.body;

  if (!files || !Array.isArray(files) || files.length === 0) {
    return res.status(400).json({ error: 'No files to upload' });
  }

  if (!UPLOADTHING_API_KEY) {
    console.error('UPLOADTHING_API_KEY not configured');
    return res.status(500).json({ error: 'Upload service not configured' });
  }

  try {
    const response = await fetch('https://api.uploadthing.com/v6/prepareUpload', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Uploadthing-Api-Key': UPLOADTHING_API_KEY,
      },
      body: JSON.stringify({
        files: files,
        callbackUrl: callbackUrl,
        callbackSlug: callbackSlug,
        routeConfig: ['image'],
        metadata: metadata,
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('UploadThing API Error:', errorText);
      return res.status(response.status).json({ error: 'Failed to prepare upload' });
    }

    const data = await response.json();
    res.json(data);
  } catch (error) {
    console.error('Upload preparation error:', error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
});

// Optional: Add a callback endpoint to handle upload completion
app.post('/api/upload-callback', async (req, res) => {
  try {
    const { files, callbackSlug } = req.body;
    
    // You can process the uploaded files here
    // For example, save file information to MongoDB
    if (files && files.length > 0) {
      const database = await getDatabase();
      const uploads = database.collection('uploads');
      
      const uploadRecord = {
        files: files,
        callbackSlug: callbackSlug,
        uploadedAt: new Date(),
      };
      
      await uploads.insertOne(uploadRecord);
      console.log('Upload record saved:', uploadRecord);
    }
    
    res.json({ success: true });
  } catch (error) {
    console.error('Upload callback error:', error);
    res.status(500).json({ error: 'Callback processing failed' });
  }
});

// Initialize MongoDB connection
connectToMongoDB();

// Start server
app.listen(port, '0.0.0.0', () => {
  console.log(`Server is running on port ${port}`);
});

// Graceful shutdown
process.on('SIGINT', async () => {
  try {
    await client.close();
    console.log('MongoDB connection closed through app termination');
    process.exit(0);
  } catch (err) {
    console.error('Error during shutdown:', err);
    process.exit(1);
  }
});