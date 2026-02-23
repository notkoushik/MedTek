/**
 * test_ollama_triage.js
 * 
 * Comprehensive test script for the local Ollama model OptGPT-4:latest
 * Tests connectivity, model info, and triage prompts in multiple languages.
 * 
 * Usage: node scripts/test_ollama_triage.js
 * 
 * Config:
 *   OLLAMA_URL  = http://192.168.1.117:8006/api/generate
 *   MODEL_NAME  = OptGPT-4:latest
 */

const http = require('http');
const fs = require('fs');
const path = require('path');

// ─── Configuration ────────────────────────────────────────────────────────────
const OLLAMA_URL = 'http://192.168.1.117:8006/api/generate';
const MODEL_NAME = 'OptGPT-4:latest';
const BASE_URL = 'http://192.168.1.117:8006';
const TIMEOUT_MS = 60000; // 60 seconds per request
const RESULTS_FILE = path.join(__dirname, 'ollama_test_results.txt');

// ─── Triage System Prompt ─────────────────────────────────────────────────────
const TRIAGE_SYSTEM_PROMPT = `You are MedTek's AI Triage Assistant.
Your goal is to help patients identify which medical specialist they should see based on their symptoms.
- tone: Be empathetic, professional, and concise (keep responses under 80 words).
- safety: DO NOT provide medical diagnoses. If emergency, advise calling help immediately.
- formatting: plain text only (no markdown).
-   hhhhh language: Always respond in the SAME language the patient uses.`;

// ─── Test Cases ───────────────────────────────────────────────────────────────
const TEST_CASES = [
    // --- Multi-Language Tests ---
    {
        category: 'LANGUAGE TEST',
        lang: 'English 🇬🇧',
        message: 'I have a headache and fever for 2 days. What should I do?',
    },
    {
        category: 'LANGUAGE TEST',
        lang: 'Hindi 🇮🇳',
        message: 'मुझे 2 दिनों से सिरदर्द और बुखार है। मुझे क्या करना चाहिए?',
    },
    {
        category: 'LANGUAGE TEST',
        lang: 'Telugu 🇮🇳',
        message: 'నాకు 2 రోజులుగా తలనొప్పి మరియు జ్వరం ఉంది. నేను ఏమి చేయాలి?',
    },
    {
        category: 'LANGUAGE TEST',
        lang: 'Tamil 🇮🇳',
        message: 'எனக்கு 2 நாட்களாக தலைவலி மற்றும் காய்ச்சல் உள்ளது. நான் என்ன செய்ய வேண்டும்?',
    },
    {
        category: 'LANGUAGE TEST',
        lang: 'Arabic 🇸🇦',
        message: 'أعاني من صداع وحمى منذ يومين. ماذا يجب أن أفعل؟',
    },
    {
        category: 'LANGUAGE TEST',
        lang: 'Kannada 🇮🇳',
        message: 'ನನಗೆ 2 ದಿನಗಳಿಂದ ತಲೆನೋವು ಮತ್ತು ಜ್ವರ ಇದೆ. ನಾನು ಏನು ಮಾಡಬೇಕು?',
    },

    // --- Medical Scenario Tests (English) ---
    {
        category: 'SYMPTOM TEST',
        lang: 'Chest Pain',
        message: 'I have severe chest pain radiating to my left arm. It started 30 minutes ago.',
    },
    {
        category: 'SYMPTOM TEST',
        lang: 'Stomach Ache',
        message: 'I have sharp pain in my lower right abdomen. It has been getting worse for 6 hours.',
    },
    {
        category: 'SYMPTOM TEST',
        lang: 'Breathing Difficulty',
        message: 'I am having trouble breathing and my lips look slightly blue. I feel dizzy.',
    },
    {
        category: 'SYMPTOM TEST',
        lang: 'Skin Rash',
        message: 'I have a red itchy rash spreading across my arms and chest since yesterday.',
    },
    {
        category: 'SYMPTOM TEST',
        lang: 'Mental Health',
        message: 'I have been feeling very anxious and depressed for the past month. I can\'t sleep.',
    },
];

// ─── Utility: HTTP Request ────────────────────────────────────────────────────
function httpRequest(options, body = null) {
    return new Promise((resolve, reject) => {
        const req = http.request(options, (res) => {
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => {
                resolve({ statusCode: res.statusCode, body: data });
            });
        });

        req.on('error', reject);
        req.setTimeout(TIMEOUT_MS, () => {
            req.destroy();
            reject(new Error(`Request timed out after ${TIMEOUT_MS / 1000}s`));
        });

        if (body) req.write(body);
        req.end();
    });
}

// ─── Step 1: Check Connectivity ───────────────────────────────────────────────
async function checkConnectivity() {
    log('\n' + '═'.repeat(60));
    log('STEP 1: CONNECTIVITY CHECK');
    log('═'.repeat(60));
    log(`Target: ${BASE_URL}`);

    try {
        const url = new URL(BASE_URL);
        const result = await httpRequest({
            hostname: url.hostname,
            port: url.port,
            path: '/',
            method: 'GET',
            timeout: 5000,
        });
        log(`✅ Server is reachable! Status: ${result.statusCode}`);
        return true;
    } catch (err) {
        log(`❌ Cannot reach server: ${err.message}`);
        log('   Make sure Ollama is running and accessible on your WiFi network.');
        return false;
    }
}

// ─── Step 2: Get Available Models ─────────────────────────────────────────────
async function getAvailableModels() {
    log('\n' + '═'.repeat(60));
    log('STEP 2: AVAILABLE MODELS');
    log('═'.repeat(60));

    try {
        const url = new URL(BASE_URL);
        const result = await httpRequest({
            hostname: url.hostname,
            port: url.port,
            path: '/api/tags',
            method: 'GET',
        });

        if (result.statusCode === 200) {
            const data = JSON.parse(result.body);
            const models = data.models || [];
            log(`✅ Found ${models.length} model(s):`);
            models.forEach((m, i) => {
                const sizeGB = m.size ? (m.size / 1e9).toFixed(2) + ' GB' : 'unknown size';
                log(`   ${i + 1}. ${m.name} (${sizeGB})`);
                if (m.details) {
                    log(`      Family: ${m.details.family || 'N/A'}`);
                    log(`      Parameters: ${m.details.parameter_size || 'N/A'}`);
                    log(`      Quantization: ${m.details.quantization_level || 'N/A'}`);
                }
            });

            const hasTarget = models.some(m => m.name.toLowerCase().includes('optgpt'));
            if (hasTarget) {
                log(`\n✅ Target model "${MODEL_NAME}" is available!`);
            } else {
                log(`\n⚠️  Target model "${MODEL_NAME}" was NOT found in the list above.`);
                log('   The test will still attempt to use it.');
            }
            return models;
        } else {
            log(`⚠️  /api/tags returned status ${result.statusCode}`);
            return [];
        }
    } catch (err) {
        log(`❌ Failed to get models: ${err.message}`);
        return [];
    }
}

// ─── Step 3: Get Model Info ────────────────────────────────────────────────────
async function getModelInfo() {
    log('\n' + '═'.repeat(60));
    log('STEP 3: MODEL INFO');
    log(`Model: ${MODEL_NAME}`);
    log('═'.repeat(60));

    try {
        const url = new URL(BASE_URL);
        const body = JSON.stringify({ name: MODEL_NAME });

        const result = await httpRequest({
            hostname: url.hostname,
            port: url.port,
            path: '/api/show',
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(body),
            },
        }, body);

        if (result.statusCode === 200) {
            const data = JSON.parse(result.body);
            log('✅ Model info retrieved successfully!');
            log('\n--- Model Details ---');
            if (data.details) {
                log(`  Family:         ${data.details.family || 'N/A'}`);
                log(`  Format:         ${data.details.format || 'N/A'}`);
                log(`  Parameters:     ${data.details.parameter_size || 'N/A'}`);
                log(`  Quantization:   ${data.details.quantization_level || 'N/A'}`);
            }
            if (data.modelinfo) {
                const info = data.modelinfo;
                const keys = Object.keys(info).slice(0, 10); // Show first 10 keys
                keys.forEach(k => log(`  ${k}: ${JSON.stringify(info[k]).substring(0, 80)}`));
            }
            if (data.template) {
                log('\n--- Prompt Template (first 300 chars) ---');
                log(data.template.substring(0, 300));
            }
            if (data.system) {
                log('\n--- Default System Prompt ---');
                log(data.system.substring(0, 300));
            }
            return data;
        } else {
            log(`⚠️  /api/show returned status ${result.statusCode}: ${result.body.substring(0, 200)}`);
            return null;
        }
    } catch (err) {
        log(`❌ Failed to get model info: ${err.message}`);
        return null;
    }
}

// ─── Step 4: Run a Single Triage Test ─────────────────────────────────────────
async function runTriageTest(testCase) {
    const prompt = `${TRIAGE_SYSTEM_PROMPT}\n\nPatient: ${testCase.message}\n\nAssistant:`;

    const url = new URL(OLLAMA_URL);
    const body = JSON.stringify({
        model: MODEL_NAME,
        prompt: prompt,
        stream: false,
        options: {
            temperature: 0.7,
            top_p: 0.9,
            num_predict: 500,
        },
    });

    const startTime = Date.now();

    try {
        const result = await httpRequest({
            hostname: url.hostname,
            port: url.port,
            path: url.pathname,
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(body),
            },
        }, body);

        const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);

        if (result.statusCode === 200) {
            const data = JSON.parse(result.body);
            const response = data.response || '(no response)';
            const evalCount = data.eval_count || 0;
            const promptEvalCount = data.prompt_eval_count || 0;

            return {
                success: true,
                response: response.trim(),
                elapsed,
                evalCount,
                promptEvalCount,
                totalDuration: data.total_duration ? (data.total_duration / 1e9).toFixed(2) + 's' : elapsed + 's',
            };
        } else {
            return {
                success: false,
                error: `HTTP ${result.statusCode}: ${result.body.substring(0, 200)}`,
                elapsed,
            };
        }
    } catch (err) {
        const elapsed = ((Date.now() - startTime) / 1000).toFixed(1);
        return {
            success: false,
            error: err.message,
            elapsed,
        };
    }
}

// ─── Step 5: Run All Tests ─────────────────────────────────────────────────────
async function runAllTests() {
    log('\n' + '═'.repeat(60));
    log('STEP 4: TRIAGE RESPONSE TESTS');
    log(`Model: ${MODEL_NAME}`);
    log(`Endpoint: ${OLLAMA_URL}`);
    log('═'.repeat(60));

    const results = [];
    let passed = 0;
    let failed = 0;

    for (let i = 0; i < TEST_CASES.length; i++) {
        const tc = TEST_CASES[i];
        log(`\n[${i + 1}/${TEST_CASES.length}] ${tc.category} — ${tc.lang}`);
        log(`Input: "${tc.message.substring(0, 80)}${tc.message.length > 80 ? '...' : ''}"`);
        log('Waiting for response...');

        const result = await runTriageTest(tc);

        if (result.success) {
            passed++;
            log(`✅ Response (${result.elapsed}s | ${result.evalCount} tokens):`);
            log(`   "${result.response}"`);
        } else {
            failed++;
            log(`❌ FAILED (${result.elapsed}s): ${result.error}`);
        }

        results.push({ ...tc, result });
    }

    return { results, passed, failed };
}

// ─── Logging ──────────────────────────────────────────────────────────────────
const logLines = [];
function log(msg) {
    console.log(msg);
    logLines.push(msg);
}

// ─── Main ─────────────────────────────────────────────────────────────────────
async function main() {
    const timestamp = new Date().toISOString();
    log('╔' + '═'.repeat(58) + '╗');
    log('║   MEDTEK OLLAMA TRIAGE MODEL TEST                       ║');
    log('╚' + '═'.repeat(58) + '╝');
    log(`Started: ${timestamp}`);
    log(`Model:   ${MODEL_NAME}`);
    log(`URL:     ${OLLAMA_URL}`);

    // Step 1: Connectivity
    const isReachable = await checkConnectivity();
    if (!isReachable) {
        log('\n❌ Aborting: Cannot reach Ollama server.');
        log('   Check that:');
        log('   1. Ollama is running on the machine at 192.168.1.117');
        log('   2. It is listening on port 8006 (OLLAMA_HOST=0.0.0.0:8006)');
        log('   3. Your computer is on the same WiFi network');
        saveResults();
        process.exit(1);
    }

    // Step 2: Available Models
    await getAvailableModels();

    // Step 3: Model Info
    await getModelInfo();

    // Step 4: Run Tests
    const { results, passed, failed } = await runAllTests();

    // Summary
    log('\n' + '═'.repeat(60));
    log('SUMMARY');
    log('═'.repeat(60));
    log(`Total Tests: ${TEST_CASES.length}`);
    log(`✅ Passed:   ${passed}`);
    log(`❌ Failed:   ${failed}`);

    const langTests = results.filter(r => r.category === 'LANGUAGE TEST');
    const symptomTests = results.filter(r => r.category === 'SYMPTOM TEST');

    log('\nLanguage Tests:');
    langTests.forEach(r => {
        const status = r.result.success ? '✅' : '❌';
        const time = r.result.elapsed + 's';
        log(`  ${status} ${r.lang.padEnd(20)} ${time}`);
    });

    log('\nSymptom Tests:');
    symptomTests.forEach(r => {
        const status = r.result.success ? '✅' : '❌';
        const time = r.result.elapsed + 's';
        log(`  ${status} ${r.lang.padEnd(20)} ${time}`);
    });

    log('\n' + '═'.repeat(60));
    log(`Completed: ${new Date().toISOString()}`);
    log('═'.repeat(60));

    saveResults();
}

function saveResults() {
    try {
        fs.writeFileSync(RESULTS_FILE, logLines.join('\n'), 'utf8');
        console.log(`\n📄 Results saved to: ${RESULTS_FILE}`);
    } catch (err) {
        console.error('Could not save results file:', err.message);
    }
}

main().catch(err => {
    log(`\n💥 Unexpected error: ${err.message}`);
    log(err.stack);
    saveResults();
    process.exit(1);
});
