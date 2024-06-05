import mongoose from "mongoose";
import dotenv from "dotenv";

dotenv.config();

const connectDB = async () => {
  try {
    const DB_OPTIONS = {
      useNewUrlParser: true,
    };
    const mongodbUrl = process.env.MONGODB_URL;
    await mongoose.connect(
      mongodbUrl,
      DB_OPTIONS
    );
    console.log("Connected to Database");
  } catch (error) {
    console.log(error);
  }
};

export default connectDB;
