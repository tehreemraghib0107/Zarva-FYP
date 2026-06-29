const fs = require('fs');
const path = require('path');
const https = require('https');

const API_KEY = 'SUWFLLticifjwPLhjva7b2Re';
const ASSETS_DIR = 'D:\\Projects\\Zarva-FYP-main\\mobile_app\\assets\\';
const OUT_DIR = 'D:\\Projects\\Zarva-FYP-main\\mobile_app\\assets\\ar\\';

const TARGET_FILES = [
    '1E.png', '2E.png', '3E.png', '4E.png', '5E.png', '6E.png', '7E.png', '8E.png', '9E.png', '10E.png',
    '1C.png', '2C.png', '3C.png', '4C.png', '5C.png', '6C.png',
    '1L.png', '2L.png',
    '2N.png', '3N.png', '4N.png', '7N.png', '8N.png',
    '1R.png', '2R.png', '3R.png',
    '1B.png', '2B.png', '3B.png'
];

function delay(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

async function removeBg(inFilePath, outFilePath, fileName) {
    return new Promise((resolve, reject) => {
        const fileData = fs.readFileSync(inFilePath);
        const boundary = '----WebKitFormBoundary' + Math.random().toString(16).slice(2);

        const postDataStart = Buffer.from(
            `--${boundary}\r\n` +
            `Content-Disposition: form-data; name="size"\r\n\r\n` +
            `auto\r\n` +
            `--${boundary}\r\n` +
            `Content-Disposition: form-data; name="image_file"; filename="${fileName}"\r\n` +
            `Content-Type: application/octet-stream\r\n\r\n`
        );
        const postDataEnd = Buffer.from(`\r\n--${boundary}--\r\n`);

        const options = {
            hostname: 'api.remove.bg',
            path: '/v1.0/removebg',
            method: 'POST',
            headers: {
                'X-Api-Key': API_KEY,
                'Content-Type': `multipart/form-data; boundary=${boundary}`,
                'Content-Length': postDataStart.length + fileData.length + postDataEnd.length
            }
        };

        const req = https.request(options, (res) => {
            if (res.statusCode !== 200) {
                let errorData = '';
                res.on('data', chunk => { errorData += chunk; });
                res.on('end', () => {
                    console.error(`Error processing ${fileName}: HTTP ${res.statusCode} ${errorData}`);
                    resolve();
                });
                return;
            }

            const chunks = [];
            res.on('data', chunk => chunks.push(chunk));
            res.on('end', () => {
                const buffer = Buffer.concat(chunks);
                fs.writeFileSync(outFilePath, buffer);
                resolve();
            });
        });

        req.on('error', (e) => {
            console.error(`Request error for ${fileName}: ${e.message}`);
            resolve();
        });

        req.write(postDataStart);
        req.write(fileData);
        req.write(postDataEnd);
        req.end();
    });
}

async function main() {
    if (!fs.existsSync(ASSETS_DIR)) {
        console.error('Assets directory not found:', ASSETS_DIR);
        return;
    }
    
    if (!fs.existsSync(OUT_DIR)) {
        fs.mkdirSync(OUT_DIR, { recursive: true });
    }

    const files = fs.readdirSync(ASSETS_DIR);
    const imageFiles = files.filter(f => TARGET_FILES.includes(f));

    for (const fileName of imageFiles) {
        console.log(`Processing: ${fileName}`);
        const inFilePath = path.join(ASSETS_DIR, fileName);
        const outFilePath = path.join(OUT_DIR, fileName);
        await removeBg(inFilePath, outFilePath, fileName);
        console.log(`Done: ${fileName}`);
        await delay(1000);
    }

    console.log("ALL DONE");
}

main();
