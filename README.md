Storage Cleaner
A SwiftUI-based iPhone storage cleaner app designed to help users identify and safely remove unnecessary
photos, screenshots, large videos, and duplicate contacts.




Features
• Storage dashboard showing device storage usage
• Similar photo detection
• Perceptual hashing with Hamming distance
• Recommended photo to keep
• Screenshot management
• Large video detection and sorting
• Duplicate contact detection
• Multi-selection
• Estimated space that can be freed
• Review screen before deletion
• Explicit confirmation before destructive actions
• Photo and Contacts permission handling
• Limited Photos access handling




Architecture
The project follows a SwiftUI MVVM-style architecture:
Views
↓
ViewModels
↓
Services / Algorithms
↓
Apple Frameworks



Technologies
• Swift
• SwiftUI
• PhotoKit
• Contacts Framework
• Observation
• Core Graphics



Similar Photo Detection
The similar-photo detection pipeline uses a lightweight on-device approach:
PHAsset
↓
128×128 Thumbnail
↓
Perceptual Hash
↓
64-bit UInt64 Hash
↓
Hamming Distance
↓
Similarity Grouping
↓
Quality Score
↓
Recommended Photo
The perceptual hash converts an image into a 64-bit fingerprint. Hamming distance is used to compare the
fingerprints and identify visually similar photos.
The quality score considers:
• Photo resolution
• Favorite status
• File size
The app only recommends which photo to keep. It does not automatically delete photos.



Project Structure
StorageCleaner/
nnn Algorithms/
nnn App/
nnn Models/
nnn Services/
nnn ViewModels/
nnn Views/



Deletion Safety
The app follows a confirmation-based cleanup flow:
Fetch
↓
Process
↓
Display
↓
Select
↓
Review
↓
Confirm
↓
Delete
Photos and videos are deleted through PhotoKit, while contacts are deleted through the Contacts
framework.



Privacy
The core processing is performed on-device using Apple's PhotoKit and Contacts frameworks. No backend
or cloud service is required for the core cleanup workflows.



Current Limitation
Final iPhone/Xcode device testing could not be performed because a Mac and physical iPhone were not
available during development.
Therefore, a TestFlight build and device screen recording are not included.


Assignment
This repository contains the source implementation for the Storage Cleaner take-home assignment
