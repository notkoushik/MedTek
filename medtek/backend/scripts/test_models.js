const { GoogleGenerativeAI } = require("@google/generative-ai");
require('dotenv').config();

async function testModel(modelName) {
    const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
    try {
        process.stdout.write(`Testing ${modelName}... `);
        const model = genAI.getGenerativeModel({ model: modelName });
        const result = await model.generateContent("Hello?");
        const response = await result.response;
        console.log(`✅ SUCCESS!`);
        return true;
    } catch (e) {
        // Log brief error to avoid clutter
        let msg = e.message || 'Unknown error';
        if (msg.includes('404')) msg = '404 Not Found';
        console.log(`❌ FAILED (${msg})`);
        return false;
    }
}

async function runTests() {
    console.log("--- Starting Model Availability Test ---");
    const models = [
        "gemini-1.5-flash",
        "gemini-1.5-flash-001",
        "gemini-1.5-flash-latest",
        "gemini-1.5-pro",
        "gemini-pro",
        "gemini-pro-vision"
    ];

    let worked = [];
    for (const m of models) {
        if (await testModel(m)) worked.push(m);
    }
    console.log("\nWORKING MODELS: ", worked);
    console.log("--- End Test ---");
}

runTests();
