//
//  SupabaseConfig.swift
//  SplitLens
//
//  Configuration for Supabase backend services
//

import Foundation

/// Supabase configuration struct
struct SupabaseConfig {
    
    // MARK: - Configuration Properties
    
    /// Supabase project URL (e.g., "https://xxxxx.supabase.co")
    let projectURL: String
    
    /// Supabase anonymous (public) API key
    let apiKey: String
    
    /// OCR Edge Function URL
    let ocrFunctionURL: String
    
    /// Whether to use mock services (for development/testing)
    let useMockServices: Bool
    
    // MARK: - Default Configuration
    
    /// Default configuration (reads from Info.plist values set via Config.xcconfig)
    static let `default` = SupabaseConfig(
        projectURL: Bundle.main.infoDictionary?["SUPABASE_PROJECT_URL"] as? String ?? "",
        apiKey: Bundle.main.infoDictionary?["SUPABASE_API_KEY"] as? String ?? "",
        ocrFunctionURL: Bundle.main.infoDictionary?["SUPABASE_OCR_FUNCTION_URL"] as? String ?? "",
        useMockServices: false // Set to true to use mock services for development
    )
    
    // MARK: - Validation
    
    /// Checks if all required configuration values are present
    var isConfigured: Bool {
        !projectURL.isEmpty &&
        !apiKey.isEmpty &&
        !ocrFunctionURL.isEmpty &&
        projectURL.hasPrefix("https://") &&
        apiKey.count > 20
    }
    
    /// Legacy validation for backwards compatibility
    var isValid: Bool {
        isConfigured
    }
    
    /// Validation error message if configuration is invalid
    var validationError: String? {
        if projectURL.contains("YOUR_PROJECT_REF") {
            return "Supabase project URL not configured. Please update SupabaseConfig.swift"
        }
        if apiKey.contains("YOUR_ANON_KEY") {
            return "Supabase API key not configured. Please update SupabaseConfig.swift"
        }
        return nil
    }
}

// MARK: - Setup Instructions

/*
 
 🚀 SUPABASE SETUP INSTRUCTIONS
 ═══════════════════════════════════════════════════════════
 
 To connect this app to your Supabase backend:
 
 1. CREATE A SUPABASE PROJECT
    - Go to https://supabase.com
    - Sign up or log in
    - Create a new project
    - Wait for provisioning (2-3 minutes)
 
 2. GET YOUR CREDENTIALS
    - In Supabase dashboard, go to Settings → API
    - Copy your:
      • Project URL (looks like: https://xxxxx.supabase.co)
      • anon/public API key (starts with: eyJhbGc...)
 
 3. UPDATE THIS FILE
    Replace the placeholder values in the `default` configuration above:
    
    ```swift
    static let `default` = SupabaseConfig(
        projectURL: "https://YOUR_ACTUAL_PROJECT_REF.supabase.co",
        apiKey: "eyJhbGc... YOUR_ACTUAL_ANON_KEY",
        ocrFunctionURL: "https://YOUR_ACTUAL_PROJECT_REF.supabase.co/functions/v1/extract-receipt-data",
        useMockServices: false // Set to false to use real Supabase
    )
    ```
 
 4. ALTERNATIVE: ENVIRONMENT VARIABLES
    Instead of hardcoding, you can set environment variables:
    - SUPABASE_URL
    - SUPABASE_API_KEY
    - SUPABASE_OCR_URL
    
    In Xcode: Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables
 
 5. DATABASE SETUP
    Run this SQL in your Supabase SQL Editor:
    
    ```sql
    CREATE TABLE receipt_sessions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
        participants TEXT[] NOT NULL,
        total_amount NUMERIC NOT NULL,
        paid_by TEXT NOT NULL,
        items JSONB NOT NULL,
        computed_splits JSONB NOT NULL,
        user_id UUID
    );
    
    CREATE INDEX idx_receipt_sessions_created_at ON receipt_sessions(created_at DESC);
    CREATE INDEX idx_receipt_sessions_user_id ON receipt_sessions(user_id);
    
    -- Enable Row Level Security
    ALTER TABLE receipt_sessions ENABLE ROW LEVEL SECURITY;
    
    -- Allow public access (for development - restrict this later!)
    CREATE POLICY "Allow public read access" ON receipt_sessions FOR SELECT USING (true);
    CREATE POLICY "Allow public insert access" ON receipt_sessions FOR INSERT WITH CHECK (true);
    CREATE POLICY "Allow public delete access" ON receipt_sessions FOR DELETE USING (true);
    ```
 
 6. VERIFY CONNECTION
    - Set useMockServices to false
    - Build and run the app
    - Try saving a session
    - Check Supabase dashboard → Table Editor → receipt_sessions
 
 ═══════════════════════════════════════════════════════════
 
 📝 NOTES:
 - For Part 1, we're using mock services (useMockServices = true)
 - Part 2 will implement the OCR Edge Function
 - Later parts will add authentication and proper RLS policies
 
 ═══════════════════════════════════════════════════════════
 
 */
