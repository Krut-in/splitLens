# SplitLens - iOS Receipt Scanner App

A production-grade iOS application for scanning receipts and splitting bills among multiple people.

## 📱 Project Overview

SplitLens is built with:
- **SwiftUI** for modern, declarative UI
- **MVVM + Service Layer** architecture
- **iOS 18.0+** deployment target
- **Supabase** backend integration
- **Native iOS frameworks** (no third-party dependencies for Part 1)

## 🏗️ Architecture

### MVVM Pattern with Dependency Injection

```
SplitLens/
├── Models/                     # Data models
│   ├── ReceiptItem.swift
│   ├── ReceiptSession.swift
│   └── SplitLog.swift
├── Services/                   # Business logic layer
│   ├── OCRService.swift
│   ├── SupabaseService.swift
│   ├── BillSplitEngine.swift
│   ├── ReportGenerationEngine.swift
│   └── DependencyContainer.swift
├── ViewModels/                 # Presentation logic
│   ├── ImageUploadViewModel.swift
│   ├── ItemsEditorViewModel.swift
│   ├── ParticipantsViewModel.swift
│   ├── AssignmentViewModel.swift
│   ├── ReportViewModel.swift
│   └── HistoryViewModel.swift
├── Views/                      # UI components
│   └── ContentView.swift
├── Configuration/              # App configuration
│   └── SupabaseConfig.swift
└── Utilities/                  # Helper utilities
    └── ErrorHandling.swift
```

## 🚀 Getting Started

### Prerequisites

- **Xcode 15.3+** (for iOS 18.0 support)
- **macOS 14.0+** (Sonoma)
- **iOS 18.0+ Simulator** or physical device

### Opening the Project

```bash
cd /Users/krutinrahtod/Desktop/Desktop/WEB/webCodes/latestCodee/splitLens
open SplitLens.xcodeproj
```

### Building and Running

1. Open `SplitLens.xcodeproj` in Xcode
2. Select **iPhone 16 Pro** simulator (or any iOS 18+ device)
3. Press **⌘ + R** to build and run

The app will launch with a welcome screen showing Part 1 foundation is complete.

## 🔧 Supabase Configuration

### Quick Start (Using Mock Services)

By default, the app uses **mock services** for development. No Supabase setup is required for Part 1.

### Connecting to Real Supabase (Optional)

See the comprehensive setup guide:
- [Supabase Setup Guide](./SUPABASE_SETUP.md)

Or follow these quick steps:

1. **Create Supabase Project** at [supabase.com](https://supabase.com)
2. **Get Credentials**: Settings → API → Copy Project URL and anon key
3. **Update Configuration**: Edit `SplitLens/Configuration/SupabaseConfig.swift`:
   ```swift
   static let `default` = SupabaseConfig(
       projectURL: "https://YOUR_PROJECT.supabase.co",
       apiKey: "YOUR_ANON_KEY",
       ocrFunctionURL: "https://YOUR_PROJECT.supabase.co/functions/v1/extract-receipt-data",
       useMockServices: false  // Set to false!
   )
   ```
4. **Run SQL Setup** in Supabase SQL Editor (see SUPABASE_SETUP.md)

## ✨ Features Implemented (Part 1)

### ✅ Core Data Models
- `ReceiptItem` - Individual line items with multi-person assignment
- `ReceiptSession` - Complete session with participants and splits
- `SplitLog` - Payment transfer records

### ✅ Service Layer (Protocol-Based)
- **OCRService** - Receipt image processing (currently mock)
- **SupabaseService** - Database CRUD operations
- **BillSplitEngine** - Multi-person split calculations
- **ReportGenerationEngine** - Multiple report formats

### ✅ ViewModels (@MainActor)
- **ImageUploadViewModel** - Camera/photo library integration
- **ItemsEditorViewModel** - Item CRUD with validation
- **ParticipantsViewModel** - Participant management
- **AssignmentViewModel** - Item-to-person assignment
- **ReportViewModel** - Final calculations and export
- **HistoryViewModel** - Session history with search/filter

### ✅ Foundation Components
- Centralized dependency injection
- Comprehensive error handling
- Async/await throughout
- Type-safe, protocol-based design

## 📋 Coding Standards

All code follows strict production standards:

✅ No force unwraps (`!`)  
✅ Async/await for all async operations  
✅ Files under 300 lines  
✅ `@MainActor` for ViewModels  
✅ Protocol-based services  
✅ Comprehensive error handling  
✅ Inline documentation  

## 🧪 Testing the Foundation

### Test the Models

```swift
let item = ReceiptItem(name: "Pizza", quantity: 1, price: 24.99)
item.assign(to: "Alice")
item.assign(to: "Bob")
print(item.pricePerPerson) // 12.495
```

### Test Bill Splitting

```swift
let engine = BillSplitEngine()
let session = ReceiptSession.sample
let splits = engine.computeSplits(session: session)
splits.forEach { print($0.summary) }
```

### Test Mock Services

```swift
let ocrService = MockOCRService()
let items = try await ocrService.extractReceiptData(from: someImage)
```

## 🗂️ Project Structure Details

### Models
All models conform to `Identifiable`, `Codable`, and `Equatable`. They include:
- Computed properties for display formatting
- Validation methods
- Helper methods for common operations

### Services
Protocol-based services with:
- Mock implementations for testing
- Real implementations for production
- Comprehensive error handling with custom error types

### ViewModels
All ViewModels:
- Use `@MainActor` for thread safety
- Conform to `ObservableObject`
- Take dependencies via initializer injection
- Separate state management from business logic

## 📦 What's Next (Part 2+)

The foundation is ready for:
- [ ] **Part 2**: OCR Edge Function implementation
- [ ] **Part 3**: UI Views and user flows
- [ ] **Part 4**: Advanced bill splitting logic
- [ ] **Part 5**: Reporting and export features
- [ ] **Part 6**: Authentication and user accounts
- [ ] **Part 7**: Polish, animations, and App Store preparation

## 🎯 Key Design Decisions

1. **Protocol-Based Services**: Enables easy mocking and testing
2. **Dependency Injection**: Centralized in `DependencyContainer`
3. **MVVM Pattern**: Clear separation of concerns
4. **Async/Await**: Modern concurrency throughout
5. **Mock-First Development**: Can develop without backend
6. **Type Safety**: Leverages Swift's type system fully

## 📝 Notes

- **Current Status**: Part 1 Foundation Complete ✅
- **Mock Services**: Currently active for development
- **iOS Version**: Configured for iOS 18.0+
- **Simulator**: Tested on iPhone 16 Pro

## 🤝 Contributing

This is a structured learning project following a 5-part implementation plan.

## 📄 License

Educational project for learning iOS development.

---

**Built with ❤️ using SwiftUI, MVVM, and Supabase**
