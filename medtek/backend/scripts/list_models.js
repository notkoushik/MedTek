require('dotenv').config();
const { GoogleGenerativeAI } = require('@google/generative-ai');

async function listModels() {
    const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    // Current SDK might not expose listModels directly on genAI, usually it's on a manager or via model.
    // Actually, standard google-generative-ai node SDK doesn't have a top-level listModels helper easily exposed in all versions.
    // But let's check if we can verify the model another way, or use the raw API if needed.
    // Wait, the error suggests "Call ListModels".
    // The SDK might NOT have listModels. Let's try to just hit the REST API to be sure.

    // Alternative: try to just invoke 'gemini-1.5-flash-001' which is the versioned name.
    console.log("Checking commonly known model names...");
}

// Better approach: Use curl or simple fetch to list models if SDK is obscure.
// API: GET https://generativelanguage.googleapis.com/v1beta/models?key=API_KEY

const https = require('https');

const apiKey = process.env.GEMINI_API_KEY;
const url = `https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey}`;

https.get(url, (res) => {
    let data = '';
    res.on('data', (chunk) => data += chunk);
    res.on('end', () => {
        try {
            const json = JSON.parse(data);
            if (json.models) {
                console.log("✅ Available Models:");
                json.models.forEach(m => console.log(` - ${m.name}`));
            } else {
                console.error("❌ Error listing models:", json);
            }
        } catch (e) {
            console.error("❌ Failed to parse response", data);
        }
    });
}).on('error', (e) => {
    console.error("❌ Network error", e);
});
