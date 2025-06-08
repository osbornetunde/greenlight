# Greenlight API

## Docker Deployment

This project includes a Dockerfile for containerized deployment. The Dockerfile:

1. Builds the application in a Go environment
2. Creates a minimal runtime image with only the necessary dependencies
3. Sets up the application to run with proper permissions
4. Configures environment variables for deployment

### Building the Docker Image

```bash
docker build -t greenlight-api .
```

### Running the Docker Container Locally

```bash
docker run -p 4000:4000 -e DATABASE_URL=your_database_connection_string greenlight-api
```

### Deploying with Railway

When deploying to Railway, the platform will automatically:
1. Detect the Dockerfile and build the image
2. Set up the necessary environment variables
3. Deploy the container with the appropriate configuration

Make sure to set the DATABASE_URL environment variable in your Railway project to connect to your PostgreSQL database.

## How to Deploy to Railway.com (Like You're 5 Years Old)

Hello friend! Let's put our Greenlight app on the internet using Railway.com! It's like building a LEGO tower and showing it to everyone!

### Step 1: Get Ready
1. Ask a grown-up to help you make an account on [Railway.com](https://railway.com)
2. Install Railway on your computer:
   ```
   npm install -g @railway/cli
   ```
3. Login to Railway:
   ```
   railway login
   ```

### Step 2: Connect Your Project
1. Go to your Greenlight folder on your computer
2. Tell Railway about your project:
   ```
   railway init
   ```
3. When it asks questions, just pick the options that make sense to you!

### Step 3: Add a Database
1. In the Railway website, click on "New Project"
2. Click "Provision PostgreSQL"
3. This gives your app a special place to store information, like a toy box!

### Step 4: Connect Your App to the Database
1. In the Railway website, go to your project
2. Click on the PostgreSQL database
3. Look for "Connect" and copy the "DATABASE_URL"
4. Go back to your project settings
5. Click on "Variables"
6. Make sure there's a variable called "DATABASE_URL" with the value you copied

### Step 5: Send Your App to Railway
1. Go back to your computer
2. Make sure you're in your Greenlight folder
3. Tell Railway to take your app:
   ```
   railway up
   ```
4. Wait while Railway builds your app (like putting together a puzzle!)

### Step 6: Tell Everyone About Your App
1. In the Railway website, go to your project
2. Click on "Settings" and then "Generate Domain"
3. Railway will give your app a special address on the internet
4. Now you can share this address with your friends!

### Step 7: Check If Your App Is Working
1. Visit your app's address in a web browser
2. Add "/v1/healthcheck" to the end of the address
3. If you see a happy message, your app is working! Hooray!

That's it! You've put your app on the internet, just like a real programmer! 🎉
