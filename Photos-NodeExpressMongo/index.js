import express from "express";
import cors from "cors";
import multer from "multer";
import fs from "fs";
import path from "path";

const app = express();

app.use(cors());
app.use(express.json());

const PASSWORD = "arjunrajput";

// Authentication middleware
const authenticate = (req, res, next) => {
  const authHeader = req.headers["authorization"];
  if (!authHeader || authHeader !== PASSWORD) {
    return res.status(401).send("Unauthorized");
  }
  next();
};

app.get("/test", (req, res) => {
  return res.json(`Hello! Testing the HomeService Server API`);
});

// Set up multer for file uploads
const upload = multer({ dest: "uploads/" });

// Define photo upload route
app.post("/upload", authenticate, upload.single("photo"), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).send("No file uploaded.");
    }

    // Get the uploaded file details
    const originalName = req.file.originalname;
    const filePath = req.file.path;

    // Get the current date
    const uploadDate = new Date();

    // Create folder structure based on year and month
    const year = uploadDate.getFullYear();
    const month = ("0" + (uploadDate.getMonth() + 1)).slice(-2); // Zero padding for month
    const uploadDir = path.join(
      "D:\\Photos",
      year.toString(),
      month.toString()
    );

    // Create the directory and any necessary parent directories if they don't exist
    fs.mkdirSync(uploadDir, { recursive: true });

    // Move the uploaded file to the target directory
    const targetPath = path.join(uploadDir, originalName);
    fs.copyFileSync(filePath, targetPath);
    fs.unlinkSync(filePath);

    res.status(200).send("File uploaded successfully.");
  } catch (error) {
    console.error("Error uploading file:", error);
    res.status(500).send("Error uploading file.");
  }
});

// Define photo upload route for multiple photos
app.post(
  "/upload-multiple",
  authenticate,
  upload.array("photos"),
  async (req, res) => {
    try {
      if (!req.files || req.files.length === 0) {
        return res.status(400).send("No files uploaded.");
      }

      // Get the current date
      const uploadDate = new Date();

      // Create folder structure based on year and month
      const year = uploadDate.getFullYear();
      const month = ("0" + (uploadDate.getMonth() + 1)).slice(-2); // Zero padding for month
      const uploadDir = path.join(
        "D:\\Photos",
        year.toString(),
        month.toString()
      );

      // Create the directory and any necessary parent directories if they don't exist
      fs.mkdirSync(uploadDir, { recursive: true });

      // Move each uploaded file to the target directory
      req.files.forEach((file) => {
        const originalName = file.originalname;
        const filePath = file.path;
        const targetPath = path.join(uploadDir, originalName);
        fs.copyFileSync(filePath, targetPath);
        fs.unlinkSync(filePath);
      });

      res.status(200).send("Files uploaded successfully.");
    } catch (error) {
      console.error("Error uploading files:", error);
      res.status(500).send("Error uploading files.");
    }
  }
);

// Define the uploaded-photos endpoint
app.get("/uploaded-photos", authenticate, (req, res) => {
  const photosDir = "D:\\Photos";
  let photoPaths = [];

  // Recursive function to read directories
  const readDirectory = (dir) => {
    const files = fs.readdirSync(dir);
    files.forEach((file) => {
      const filePath = path.join(dir, file);
      const stat = fs.statSync(filePath);
      if (stat.isDirectory()) {
        readDirectory(filePath);
      } else {
        photoPaths.push(filePath);
      }
    });
  };

  try {
    readDirectory(photosDir);

    // Convert absolute paths to file names or IDs
    const photoFiles = photoPaths.map((filePath) => path.basename(filePath));
    res.json(photoFiles);
  } catch (error) {
    console.error("Error fetching uploaded photos:", error);
    res.status(500).send("Error fetching uploaded photos.");
  }
});

const PORT = 3001;
app.listen(PORT, () => {
  console.log("Server listening on port " + PORT + "...");
});
