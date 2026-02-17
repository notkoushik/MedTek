const https = require('https');
require('dotenv').config();

const apiKey = process.env.GEMINI_API_KEY;

if (!apiKey) {
    console.error("No API Key found!");
    process.exit(1);
}

const url = `https://generativelanguage.googleapis.com/v1beta/models?key=${apiKey}`;

console.log(`Querying: ${url.replace(apiKey, 'HIDDEN_KEY')}`);

const fs = require('fs');

https.get(url, (res) => {
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
        try {
            const json = JSON.parse(data);
            let output = '';
            if (json.error) {
                output = `API Error: ${JSON.stringify(json.error, null, 2)}`;
                console.error(output);
            } else if (json.models) {
                output = "Available Models:\n" + json.models.map(m => m.name).join('\n');
                console.log(output);
            } else {
                output = `Unknown response: ${JSON.stringify(json, null, 2)}`;
                console.log(output);
            }
            fs.writeFileSync('models_list.txt', output);
        } catch (e) {
            console.error("Parse Error:", e);
            fs.writeFileSync('models_list.txt', `Parse Error: ${e.message}\nRaw: ${data}`);
        }
    });
}).on('error', err => {
    console.error("Network Error:", err);
    fs.writeFileSync('models_list.txt', `Network Error: ${err.message}`);
});
