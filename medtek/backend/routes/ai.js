const express = require('express');
const router = express.Router();
const multer = require('multer');
const { GoogleGenerativeAI } = require('@google/generative-ai');

// Configure Multer (Memory Storage)
const upload = multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 5 * 1024 * 1024 } // 5MB limit
});

// Initialize Gemini
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

// System instruction for the medical assistant (Chat)
const getChatSystemPrompt = (profile) => `
You are MedTek's AI Triage Assistant. 
You are speaking to a patient with the following profile:
- Name: ${profile.name || 'Patient'}
- Age: ${profile.age || 'Unknown'}
- Gender: ${profile.gender || 'Unknown'}
- Known Allergies: ${profile.allergies || 'None'}
- Chronic Conditions: ${profile.conditions || 'None'}

Your goal is to help them identify which medical specialist they should see based on their symptoms.
- context: Consider their age and conditions in your analysis (e.g., chest pain in a 60yo is different from a 20yo).
- tone: Be empathetic, professional, and concise (keep responses under 50 words).
- safety: DO NOT provide medical diagnoses. If emergency, advise calling help immediately.
- formatting: plain text only (no markdown).
`;

// System instruction for the Pharmacist Agent (Vision)
const PHARMACIST_PROMPT = `
Act as a senior clinical pharmacist. Analyze the provided image of a pill/medication.

YOUR TASK:
1. Identify the pill (Name, Dosage, Type) based on visual markings, shape, and color.
2. Check for interactions between the IDENTIFIED pill and the user's CURRENT MEDICATIONS (provided below).
3. Determine if it is safe for the user to take.

INPUT DATA:
- Image: [Provided Image]
- User's Current Meds: [CURRENT_MEDS_LIST]

OUTPUT FORMAT:
Return strictly valid JSON. Do not include markdown code blocks.
Structure:
{
  "pill_name": "Name of the pill (or 'Unknown' if unclear)",
  "confidence": 0.0 to 1.0 (float),
  "safe": boolean (true if no major interaction),
  "description": "Brief visual description of the pill",
  "interactions": [
    { 
      "drug1": "Identified Pill Name", 
      "drug2": "Conflicting Med Name", 
      "severity": "HIGH/MODERATE/LOW", 
      "description": "Brief explanation of the interaction",
      "mechanism": "Brief mechanism of action (e.g., 'Increases bleeding risk')" 
    }
  ],
  "message": "A short, patient-friendly summary (e.g., 'This looks like Aspirin. It is safe to take with your current meds.')"
}

CRITICAL RULES:
- If confidence is below 0.6, set "safe" to false and "message" to "I cannot clearly identify this pill. Please try again or consult a doctor."
- If "CURRENT_MEDS_LIST" is empty, assume no interactions.
- Always be conservative with safety. If unsure, mark as unsafe.
`;

// Helper: Retry function with exponential backoff
async function retryWithBackoff(fn, retries = 3, delay = 1000) {
    try {
        return await fn();
    } catch (error) {
        if (retries === 0 || (!error.message.includes('429') && !error.message.includes('503'))) {
            throw error;
        }
        console.log(`⚠️ Rate limit/Transient error. Retrying in ${delay}ms... (${retries} left)`);
        await new Promise(resolve => setTimeout(resolve, delay));
        return retryWithBackoff(fn, retries - 1, delay * 2);
    }
}

router.post('/chat', async (req, res) => {
    try {
        const { message, history, userProfile } = req.body;

        if (!process.env.GEMINI_API_KEY) {
            return res.status(500).json({ error: 'GEMINI_API_KEY is not configured in backend .env' });
        }

        // Use the correct model
        const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });

        const chatHistory = (history || []).map(msg => ({
            role: msg.role === 'bot' ? 'model' : 'user',
            parts: [{ text: msg.message || msg.content || '' }]
        }));

        // Generate personalized system prompt
        const systemPrompt = getChatSystemPrompt(userProfile || {});

        const chat = model.startChat({
            history: [
                { role: 'user', parts: [{ text: systemPrompt }] },
                { role: 'model', parts: [{ text: `Understood. I have reviewed the profile for ${userProfile?.name || 'the patient'}. How can I help?` }] },
                ...chatHistory
            ],
        });

        // Wrap sendMessage with retry
        const result = await retryWithBackoff(async () => await chat.sendMessage(message));
        const response = await result.response;
        const text = response.text();

        res.json({ reply: text });

    } catch (error) {
        console.error('❌ Gemini AI Chat Error:', error);
        res.status(500).json({ error: 'Failed to generate response', details: error.message });
    }
});

// ✅ NEW: Vision Endpoint for Pill Identification
router.post('/identify-pill', upload.single('pill_image'), async (req, res) => {
    console.log('💊 /identify-pill called');
    try {
        // 1. Validate Input
        if (!req.file) {
            return res.status(400).json({ error: 'No image uploaded' });
        }
        if (!process.env.GEMINI_API_KEY) {
            return res.status(500).json({ error: 'GEMINI_API_KEY is not configured' });
        }

        const currentMeds = req.body.current_meds || '[]'; // Comes as string form-data
        console.log('   Stats:', { fileSize: req.file.size, currentMeds });

        // 2. Prepare Image for Gemini
        const imagePart = {
            inlineData: {
                data: req.file.buffer.toString('base64'),
                mimeType: req.file.mimetype,
            },
        };

        // 3. Prepare Prompt
        const currentMedsStr = Array.isArray(currentMeds) ? currentMeds.join(', ') : currentMeds;
        const prompt = PHARMACIST_PROMPT.replace('[CURRENT_MEDS_LIST]', currentMedsStr);

        // 4. Call Gemini Vision
        const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash' });

        console.log('🤖 Sending to Gemini 2.5 Flash...');

        // Wrap generateContent with retry
        const result = await retryWithBackoff(async () => await model.generateContent([prompt, imagePart]));
        const response = await result.response;
        let text = response.text();

        // 5. Clean JSON
        console.log('📦 Raw Gemini Response (First 100 chars):', text.substring(0, 100));
        text = text.replace(/```json/g, '').replace(/```/g, '').trim();

        // 6. Parse & Return
        let jsonResponse;
        try {
            jsonResponse = JSON.parse(text);
        } catch (e) {
            console.error('❌ Failed to parse JSON:', text);
            return res.status(500).json({ error: 'AI returned invalid JSON', raw: text });
        }

        res.json(jsonResponse);

    } catch (error) {
        console.error('❌ Pill ID Error:', error);
        res.status(500).json({
            error: 'Failed to identify pill',
            details: error.message,
            success: false
        });
    }
});

// ─── Ollama Triage Chat Route ─────────────────────────────────────────────────
// Calls the local Ollama model (OptGPT-4:latest) instead of Gemini.
// Same request/response format as /ai/chat so the Flutter app can switch easily.

const OLLAMA_URL = process.env.OLLAMA_URL || 'http://192.168.1.117:8006/api/generate';
const OLLAMA_MODEL = process.env.OLLAMA_MODEL || 'OptGPT-4:latest';

const LANGUAGE_NAMES = {
    'en': 'English',
    'hi': 'Hindi (हिंदी)',
    'te': 'Telugu (తెలుగు)',
    'ta': 'Tamil (தமிழ்)',
    'ar': 'Arabic (العربية)',
};

const getOllamaSystemPrompt = (profile) => {
    const langCode = profile.language || 'en';
    const langName = LANGUAGE_NAMES[langCode] || 'English';
    return `You are MedTek's AI Triage Assistant.
You are speaking to a patient with the following profile:
- Name: ${profile.name || 'Patient'}
- Age: ${profile.age || 'Unknown'}
- Gender: ${profile.gender || 'Unknown'}
- Known Allergies: ${profile.allergies || 'None'}
- Chronic Conditions: ${profile.conditions || 'None'}
- Preferred Language: ${langName}

Your goal is to help them identify which medical specialist they should see based on their symptoms.
- language: ALWAYS respond ONLY in ${langName}. Do not switch languages.
- tone: Be empathetic, professional, and concise (keep responses under 80 words).
- safety: DO NOT provide medical diagnoses. If emergency, advise calling emergency services immediately.
- formatting: plain text only (no markdown, no bullet points).`;
};

router.post('/chat-ollama', async (req, res) => {
    try {
        const { message, history, userProfile } = req.body;

        if (!message) {
            return res.status(400).json({ error: 'message is required' });
        }

        // Build conversation context from history (last 10 messages)
        const recentHistory = (history || []).slice(-10);
        let conversationContext = '';
        recentHistory.forEach(msg => {
            const role = msg.role === 'user' ? 'Patient' : 'Assistant';
            conversationContext += `${role}: ${msg.content || msg.message || ''}\n`;
        });

        // Build full prompt
        const systemPrompt = getOllamaSystemPrompt(userProfile || {});
        const fullPrompt = `${systemPrompt}\n\n${conversationContext}Patient: ${message}\n\nAssistant:`;

        console.log(`🤖 Calling Ollama model: ${OLLAMA_MODEL} at ${OLLAMA_URL}`);

        // Call Ollama API
        const ollamaResponse = await fetch(OLLAMA_URL, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                model: OLLAMA_MODEL,
                prompt: fullPrompt,
                stream: false,
                options: {
                    temperature: 0.7,
                    top_p: 0.9,
                    num_predict: 500,
                },

            }),
            signal: AbortSignal.timeout(60000), // 60s timeout
        });

        if (!ollamaResponse.ok) {
            const errText = await ollamaResponse.text();
            console.error(`❌ Ollama error ${ollamaResponse.status}:`, errText);
            return res.status(502).json({
                error: 'Ollama model returned an error',
                details: errText,
                status: ollamaResponse.status,
            });
        }

        const data = await ollamaResponse.json();
        const reply = (data.response || '').trim();

        console.log(`✅ Ollama replied (${data.eval_count || 0} tokens): "${reply.substring(0, 80)}..."`);

        res.json({
            reply,
            model: OLLAMA_MODEL,
            tokens: data.eval_count || 0,
            duration: data.total_duration ? (data.total_duration / 1e9).toFixed(2) + 's' : null,
        });

    } catch (error) {
        console.error('❌ Ollama Chat Error:', error);

        if (error.name === 'TimeoutError' || error.code === 'ECONNREFUSED') {
            return res.status(503).json({
                error: 'Ollama server is not reachable',
                details: `Cannot connect to ${OLLAMA_URL}. Make sure Ollama is running on your WiFi network.`,
            });
        }

        res.status(500).json({ error: 'Failed to get Ollama response', details: error.message });
    }
});

// ─── Ollama Model Info Route ──────────────────────────────────────────────────
// Returns info about the Ollama model and available models.
router.get('/ollama-info', async (req, res) => {
    try {
        const baseUrl = OLLAMA_URL.replace('/api/generate', '');

        // Get available models
        const tagsResponse = await fetch(`${baseUrl}/api/tags`, {
            signal: AbortSignal.timeout(10000),
        });

        let models = [];
        if (tagsResponse.ok) {
            const tagsData = await tagsResponse.json();
            models = tagsData.models || [];
        }

        // Get model details
        let modelInfo = null;
        try {
            const showResponse = await fetch(`${baseUrl}/api/show`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ name: OLLAMA_MODEL }),
                signal: AbortSignal.timeout(10000),
            });
            if (showResponse.ok) {
                modelInfo = await showResponse.json();
            }
        } catch (e) {
            console.warn('Could not get model details:', e.message);
        }

        res.json({
            ollamaUrl: OLLAMA_URL,
            modelName: OLLAMA_MODEL,
            availableModels: models.map(m => ({
                name: m.name,
                size: m.size ? (m.size / 1e9).toFixed(2) + ' GB' : 'unknown',
                details: m.details || {},
            })),
            modelDetails: modelInfo ? {
                family: modelInfo.details?.family,
                parameters: modelInfo.details?.parameter_size,
                quantization: modelInfo.details?.quantization_level,
                format: modelInfo.details?.format,
                template: modelInfo.template?.substring(0, 200),
            } : null,
        });

    } catch (error) {
        res.status(503).json({
            error: 'Cannot reach Ollama server',
            ollamaUrl: OLLAMA_URL,
            details: error.message,
        });
    }
});

module.exports = router;

