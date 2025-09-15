import SwiftUI

struct TermsAndConditionsView: View {
    @Binding var isPresented: Bool
    @Binding var hasAcceptedTerms: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Terms and Conditions")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.text)
                        
                        Text("PeakSet - AI Fitness Coach")
                            .font(.title2)
                            .foregroundColor(AppTheme.textSecondary)
                        
                        Text("Last Updated: \(Date().formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                    }
                    .padding(.bottom, 20)
                    
                    // Important Notice
                    VStack(alignment: .leading, spacing: 12) {
                        Text("⚠️ IMPORTANT NOTICE")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        
                        Text("This application is currently in BETA testing phase. The AI fitness coaching features are experimental and not supported by comprehensive research or clinical data. Use at your own risk.")
                            .font(.body)
                            .foregroundColor(AppTheme.text)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Terms Sections
                    VStack(alignment: .leading, spacing: 16) {
                        termsSection(
                            title: "1. Acceptance of Terms",
                            content: "By using PeakSet, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions. If you do not agree to these terms, please do not use this application."
                        )
                        
                        termsSection(
                            title: "2. Beta Testing Disclaimer",
                            content: "PeakSet is currently in beta testing phase. The AI-powered fitness coaching features are experimental and have not been validated through comprehensive research, clinical trials, or peer-reviewed studies. The form analysis and exercise recommendations are based on limited data and may not be accurate or appropriate for all users."
                        )
                        
                        termsSection(
                            title: "3. No Medical Advice",
                            content: "PeakSet does not provide medical advice, diagnosis, or treatment. The application is not intended to replace professional medical consultation, physical therapy, or certified personal training. Always consult with qualified healthcare professionals before beginning any exercise program, especially if you have pre-existing health conditions."
                        )
                        
                        termsSection(
                            title: "4. Assumption of Risk",
                            content: "You acknowledge and agree that participation in any exercise program involves inherent risks of injury, including but not limited to muscle strains, joint injuries, cardiovascular events, and other physical harm. You voluntarily assume all risks associated with your use of PeakSet and any exercises performed based on its recommendations."
                        )
                        
                        termsSection(
                            title: "5. Limitation of Liability",
                            content: "To the maximum extent permitted by law, PeakSet, its developers, and affiliates shall not be liable for any direct, indirect, incidental, special, consequential, or punitive damages arising from your use of the application, including but not limited to personal injury, property damage, or any other losses."
                        )
                        
                        termsSection(
                            title: "6. No Warranties",
                            content: "PeakSet is provided 'as is' without any warranties, express or implied. We make no representations or warranties regarding the accuracy, reliability, completeness, or suitability of the AI coaching features, form analysis, or exercise recommendations."
                        )
                        
                        termsSection(
                            title: "7. User Responsibility",
                            content: "You are solely responsible for: (a) ensuring your physical condition is suitable for exercise, (b) consulting with healthcare professionals before beginning any fitness program, (c) using proper form and technique during exercises, (d) stopping exercise if you experience pain or discomfort, and (e) making informed decisions about your fitness activities."
                        )
                        
                        termsSection(
                            title: "8. Data and Privacy",
                            content: "PeakSet may collect and process personal data, including biometric information from camera analysis. By using the application, you consent to such data collection and processing. We implement reasonable security measures, but cannot guarantee absolute security of your data."
                        )
                        
                        termsSection(
                            title: "9. Modification of Terms",
                            content: "We reserve the right to modify these Terms and Conditions at any time. Continued use of PeakSet after such modifications constitutes acceptance of the updated terms."
                        )
                        
                        termsSection(
                            title: "10. Termination",
                            content: "We reserve the right to terminate or suspend your access to PeakSet at any time, with or without notice, for any reason, including violation of these terms."
                        )
                        
                        termsSection(
                            title: "11. Governing Law",
                            content: "These Terms and Conditions shall be governed by and construed in accordance with applicable laws, without regard to conflict of law principles."
                        )
                        
                        termsSection(
                            title: "12. Contact Information",
                            content: "If you have any questions about these Terms and Conditions, please contact us through the application or at our designated support channels."
                        )
                    }
                    
                    // Final Warning
                    VStack(alignment: .leading, spacing: 12) {
                        Text("🚨 FINAL WARNING")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        
                        Text("By accepting these terms, you acknowledge that PeakSet is an experimental beta application with unvalidated AI features. You understand the risks and limitations, and you agree to use the application responsibly and at your own risk.")
                            .font(.body)
                            .foregroundColor(AppTheme.text)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }
                    .padding(.top, 20)
                }
                .padding()
            }
            .navigationTitle("Terms & Conditions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private func termsSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.text)
            
            Text(content)
                .font(.body)
                .foregroundColor(AppTheme.textSecondary)
                .lineLimit(nil)
        }
    }
}

#Preview {
    TermsAndConditionsView(isPresented: .constant(true), hasAcceptedTerms: .constant(false))
}
