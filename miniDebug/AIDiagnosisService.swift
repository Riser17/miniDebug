import Foundation

class AIDiagnosisService {
    static let shared = AIDiagnosisService()
    private init() {}

    func diagnose(error: ErrorDetail) async -> AIDiagnosis? {
        // In a real implementation, this would call an LLM API (e.g. Claude or GPT)
        // For now, we provide a mock implementation and a detailed prompt for the real one.

        let prompt = """
        You are an expert React Native and Mobile Developer.
        Analyze the following error and provide a structured diagnosis.

        Error Type: \(error.type.rawValue)
        Message: \(error.message)
        Stack Trace:
        \(error.rawStackTrace)

        Code Snippet:
        \(error.snippet ?? "No snippet available")

        Please provide:
        1. Root Cause: A concise explanation of why this happened.
        2. Suggested Fix: Step-by-step instructions to fix it.
        3. Confidence Level: High, Medium, or Low.
        4. References: Relevant documentation links if applicable.
        """

        // Simulating API latency
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        // Mock Response
        return AIDiagnosis(
            rootCause: "This is a mock diagnosis. In a real scenario, the LLM would analyze the prompt above.",
            suggestedFix: "1. Check if the module is correctly installed.\n2. Restart the Metro bundler.\n3. Run 'npm install'.",
            confidence: .medium,
            references: ["https://reactnative.dev/docs/debugging"]
        )
    }
}
