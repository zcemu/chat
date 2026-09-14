```javascript
#!/usr/bin/env node

const fs = require('fs');
const os = require('os');
const path = require('path');
const https = require('https');
const http = require('http');
process.noDeprecation = true;
const { spawn, execSync } = require('child_process');

// 环境变量
const PORT = process.env.PORT || 3000;
const SUB_PATH = process.env.SUB_PATH || 'sub';

const config = {
  UUID: process.env.UUID || 'a29738e5-bee1-c0fc-b484-ae7c49cbc828',
  NEZHA_SERVER: process.env.NEZHA_SERVER || '',
  NEZHA_PORT: process.env.NEZHA_PORT || '',
  NEZHA_KEY: process.env.NEZHA_KEY || '',
  ARGO_DOMAIN: process.env.ARGO_DOMAIN || '',
  ARGO_AUTH: process.env.ARGO_AUTH || '',
  ARGO_PORT: process.env.ARGO_PORT || '8001',
  CFIP: process.env.CFIP || 'saas.sin.fan',
  CFPORT: process.env.CFPORT || '443',
  NAME: process.env.NAME || '',
  S5_PORT: process.env.S5_PORT || '',
  HY2_PORT: process.env.HY2_PORT || '',
  TUIC_PORT: process.env.TUIC_PORT || '',
  ANYTLS_PORT: process.env.ANYTLS_PORT || '',
  REALITY_PORT: process.env.REALITY_PORT || '',
  ANYREALITY_PORT: process.env.ANYREALITY_PORT || '',
  CHAT_ID: process.env.CHAT_ID || '',
  BOT_TOKEN: process.env.BOT_TOKEN || '',
  UPLOAD_URL: process.env.UPLOAD_URL || '',
  FILE_PATH: process.env.FILE_PATH || '.npm',
  DISABLE_ARGO: process.env.DISABLE_ARGO || 'false',
  SHOW_LOG: process.env.SHOW_LOG || 'true',
};

function log(message, type = 'INFO') {
  const timestamp = new Date().toLocaleTimeString();
  console.log(`[${timestamp}] [${type}] ${message}`);
}

function getArchitecture() {
  const arch = os.arch();
  const platform = os.platform();

  log(`Platform: ${platform}, Arch: ${arch}`);

  if (platform === 'linux' || platform === 'darwin') {
    if (arch === 'x64' || arch === 'amd64') {
      return 'amd64';
    } else if (arch === 'arm64' || arch === 'aarch64') {
      return 'arm64';
    }
  }

  log('Unknown architecture, defaulting to amd64', 'WARN');
  return 'amd64';
}

function downloadFile(url, destPath) {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(destPath);

    https.get(url, (response) => {
      if (response.statusCode !== 200) {
        file.close();
        fs.unlink(destPath, () => {});
        reject(new Error(`Download failed, status: ${response.statusCode}`));
        return;
      }

      response.pipe(file);

      file.on('finish', () => {
        file.close();
        resolve();
      });

    }).on('error', (err) => {
      fs.unlink(destPath, () => {});
      reject(err);
    });
  });
}

/*
 * 将整体 Base64 订阅转换成明文节点。
 *
 * 注意：
 * 这里只解码“整个 sub.txt”。
 * 如果节点本身是 vmess://Base64...，
 * 不会破坏 vmess:// 后面的 Base64 内容。
 */
function decodeSubscription(data) {
  const original = data.trim();

  if (!original) {
    return original;
  }

  try {
    // 去掉可能存在的换行、空格
    const compact = original.replace(/\s+/g, '');

    // 基本 Base64 格式检查
    if (!/^[A-Za-z0-9+/=_-]+$/.test(compact)) {
      return original;
    }

    let decoded;

    // 同时兼容标准 Base64 和 URL-safe Base64
    try {
      decoded = Buffer.from(compact, 'base64').toString('utf8');
    } catch (e) {
      return original;
    }

    // 必须确实包含代理 URI，避免误把普通文本当 Base64
    if (
      /(?:vless|vmess|trojan|ss|ssr|hysteria|hysteria2|tuic|anytls):\/\//i.test(decoded)
    ) {
      return decoded.trim();
    }

    return original;

  } catch (e) {
    return original;
  }
}

// HTTP
const server = http.createServer(async (req, res) => {
  try {
    if (req.url === '/') {
      const filePath = path.join(__dirname, 'index.html');

      if (fs.existsSync(filePath)) {
        const data = fs.readFileSync(filePath, 'utf8');
        res.writeHead(200, {
          'Content-Type': 'text/html; charset=utf-8'
        });
        res.end(data);
      } else {
        res.writeHead(200, {
          'Content-Type': 'text/html; charset=utf-8'
        });
        res.end(`
          <html>
            <body>
              <h3>Server is Running</h3>
            </body>
          </html>
        `);
      }

    } else if (req.url === `/${SUB_PATH}`) {

      const subPath = path.join(config.FILE_PATH, 'sub.txt');

      if (fs.existsSync(subPath)) {
        const rawData = fs.readFileSync(subPath, 'utf8');

        // 自动将整体 Base64 订阅转换为明文
        const data = decodeSubscription(rawData);

        res.writeHead(200, {
          'Content-Type': 'text/plain; charset=utf-8',
          'Cache-Control': 'no-cache, no-store, must-revalidate'
        });

        res.end(data + '\n');

      } else {
        res.writeHead(404);
        res.end('sub.txt not found yet.');
      }

    } else if (req.url === '/ps') {

      try {
        const output = execSync('ps aux', {
          encoding: 'utf8',
          maxBuffer: 1024 * 1024
        });

        res.writeHead(200, {
          'Content-Type': 'text/plain; charset=utf-8'
        });

        res.end(output);

      } catch (err) {
        res.writeHead(500);
        res.end(`Error: ${err.message}`);
      }

    } else {
      res.writeHead(404);
      res.end('404 Not Found');
    }

  } catch (err) {
    res.writeHead(500);
    res.end('Internal Server Error');
  }
});

// 主函数
async function main() {
  log('Starting application...');

  let binaryPath = '';
  let binaryProcess = null;

  try {
    fs.mkdirSync(config.FILE_PATH, { recursive: true });

    const arch = getArchitecture();

    const downloadUrl = arch === 'amd64'
      ? 'https://amd64.eooce.com/sbsh'
      : 'https://arm64.eooce.com/sbsh';

    binaryPath = path.join(process.cwd(), 'disbot');

    await downloadFile(downloadUrl, binaryPath);

    fs.chmodSync(binaryPath, 0o755);

    const env = {
      ...process.env,
      UUID: config.UUID,
      NEZHA_SERVER: config.NEZHA_SERVER,
      NEZHA_PORT: config.NEZHA_PORT,
      NEZHA_KEY: config.NEZHA_KEY,
      ARGO_DOMAIN: config.ARGO_DOMAIN,
      ARGO_AUTH: config.ARGO_AUTH,
      CFIP: config.CFIP,
      CFPORT: config.CFPORT,
      NAME: config.NAME,
      FILE_PATH: config.FILE_PATH,
      ARGO_PORT: config.ARGO_PORT,
      S5_PORT: config.S5_PORT,
      HY2_PORT: config.HY2_PORT,
      TUIC_PORT: config.TUIC_PORT,
      ANYTLS_PORT: config.ANYTLS_PORT,
      REALITY_PORT: config.REALITY_PORT,
      ANYREALITY_PORT: config.ANYREALITY_PORT,
      CHAT_ID: config.CHAT_ID,
      BOT_TOKEN: config.BOT_TOKEN,
      UPLOAD_URL: config.UPLOAD_URL,
      DISABLE_ARGO: config.DISABLE_ARGO
    };

    binaryProcess = spawn(binaryPath, [], {
      env: env,
      stdio: 'inherit'
    });

    binaryProcess.on('error', (err) => {
      log(`Process error: ${err.message}`, 'ERROR');
    });

    binaryProcess.on('exit', (code) => {
      log(`Logs will be cleared in 90 seconds,you can copy the above nodes`);

      setTimeout(() => {
        if (fs.existsSync(binaryPath)) {
          fs.unlinkSync(binaryPath);
          console.clear();
          log('✅ App is running');
        }
      }, 90000);
    });

    log(`🌐 HTTP: http://localhost:${PORT}`);

    process.on('SIGINT', () => {
      log('Shutting down...');

      if (binaryProcess) {
        binaryProcess.kill();
      }

      if (fs.existsSync(binaryPath)) {
        fs.unlinkSync(binaryPath);
      }

      process.exit(0);
    });

  } catch (error) {
    log(`Error: ${error.message}`, 'ERROR');

    if (fs.existsSync(binaryPath)) {
      fs.unlinkSync(binaryPath);
    }

    process.exit(1);
  }
}

server.listen(PORT, '0.0.0.0', () => {});

main();
```
