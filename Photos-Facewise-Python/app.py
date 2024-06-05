import os
import shutil
import face_recognition


def get_image_files(directory):
    image_files = []
    for root, _, files in os.walk(directory):
        for file in files:
            if file.lower().endswith((".jpg", ".jpeg", ".png", ".bmp", ".tif", ".tiff", ".heic", ".heif")):
                image_files.append(os.path.join(root, file))
    return image_files


def load_known_faces(known_faces_dir):
    known_encodings = []
    known_names = []
    for file in os.listdir(known_faces_dir):
        if file.lower().endswith((".jpg", ".jpeg", ".png")):
            img_path = os.path.join(known_faces_dir, file)
            img = face_recognition.load_image_file(img_path)
            encodings = face_recognition.face_encodings(img)
            if encodings:
                known_encodings.append(encodings[0])
                # Use filename (without extension) as the name
                known_names.append(os.path.splitext(file)[0])
    return known_encodings, known_names


def recognize_faces_in_image(image_path, known_encodings, known_names):
    img = face_recognition.load_image_file(image_path)
    face_locations = face_recognition.face_locations(img)
    face_encodings = face_recognition.face_encodings(img, face_locations)
    recognized_faces = []
    for face_encoding in face_encodings:
        matches = face_recognition.compare_faces(
            known_encodings, face_encoding)
        name = "Unknown"
        if True in matches:
            first_match_index = matches.index(True)
            name = known_names[first_match_index]
        recognized_faces.append(name)
    return recognized_faces, face_encodings


def save_new_face(face_encoding, known_faces_dir, unknown_count):
    new_name = f"Unknown_{unknown_count}"
    new_face_path = os.path.join(known_faces_dir, new_name + ".jpg")
    # Save the face encoding
    known_encodings.append(face_encoding)
    known_names.append(new_name)
    return new_name


# Get paths from the user
print("Enter the paths where images are located (separated by commas):")
paths = ["D:\\Photos\\2024\\test"]
# Directory where known faces are stored
known_faces_dir = "D:\\Photos\\2024\\test\\known_faces"

# Create an empty list to store all image file paths
all_image_files = []
# Iterate through the provided paths and get all image files
for path in paths:
    path = path.strip()  # Remove leading/trailing whitespaces
    if os.path.isdir(path):
        all_image_files.extend(get_image_files(path))
    else:
        print(f"Warning: '{path}' is not a valid directory. Skipping...")

# Load known faces
known_encodings, known_names = load_known_faces(known_faces_dir)

# Create a directory to store segregated photos
output_dir = "D:\\Photos\\2024\\test\\segregated_photos"
os.makedirs(output_dir, exist_ok=True)

# Initialize the unknown face counter
unknown_count = 1

# Iterate through all images and recognize faces
for image_file in all_image_files:
    recognized_faces, face_encodings = recognize_faces_in_image(
        image_file, known_encodings, known_names)
    for name, face_encoding in zip(recognized_faces, face_encodings):
        if name == "Unknown":
            # Check if the face is already recognized as an unknown
            unknown_name = save_new_face(
                face_encoding, known_faces_dir, unknown_count)
            name = unknown_name
            unknown_count += 1
        person_dir = os.path.join(output_dir, name)
        os.makedirs(person_dir, exist_ok=True)
        shutil.copy(image_file, person_dir)

# Print the results
print("Segregation completed. Photos have been copied to respective folders.")
