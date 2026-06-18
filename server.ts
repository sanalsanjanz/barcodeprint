import { writeFileSync } from "fs";
import * as os from "os";

// --- TYPES & HELPER FUNCTIONS ---
type PrintItem = {
  companyName: string;
  itemName: string;
  barcode: string;
  price: number;
  currency: string;
};

function getCharWidth(fontSize: "2" | "3"): number {
  return fontSize === "3" ? 16 : 11;
}

function getCenteredX(text: string, isRightLabel: boolean, fontSize: "2" | "3"): number {
  const textWidth = text.length * getCharWidth(fontSize);
  const centerTarget = isRightLabel ? 465 : 155;
  const startX = Math.floor(centerTarget - textWidth / 2);
  return Math.max(isRightLabel ? 320 : 10, startX);
}

function getRightAlignedX(text: string, isRightLabel: boolean, fontSize: "2" | "3"): number {
  const textWidth = text.length * getCharWidth(fontSize);
  const rightEdgeTarget = isRightLabel ? 605 : 295;
  return Math.floor(rightEdgeTarget - textWidth);
}

function splitText(text: string, maxLength: number): [string, string] {
  if (text.length <= maxLength) return [text, ""];
  let splitIndex = text.lastIndexOf(" ", maxLength);
  if (splitIndex === -1) splitIndex = maxLength;
  const line1 = text.substring(0, splitIndex).trim();
  const line2 = text.substring(splitIndex).trim().substring(0, maxLength + 5);
  return [line1, line2];
}

const LEFT_BARCODE_X = 155 - 130;  
const RIGHT_BARCODE_X = 465 - 130; 

// --- GET LOCAL IP ADDRESS ---
function getLocalIpAddress() {
  const interfaces = os.networkInterfaces();
  for (const name of Object.keys(interfaces)) {
    for (const iface of interfaces[name]!) {
      // Skip internal (localhost) and non-IPv4 addresses
      if (iface.family === "IPv4" && !iface.internal) {
        return iface.address;
      }
    }
  }
  return "127.0.0.1";
}

// --- PRINTER COMMUNICATION ---
async function sendToPrinter(tspl: string) {
  const filePath = "C:\\PrintTest\\label.tspl";
  writeFileSync(filePath, tspl);
  const proc = Bun.spawn(["cmd", "/c", "copy", "/b", filePath, "\\\\localhost\\bacode"]);
  const exitCode = await proc.exited;
  return exitCode;
}

const PORT = 5000;
const localIp = getLocalIpAddress();

Bun.serve({
  hostname: "0.0.0.0",
  port: PORT,

  async fetch(req) {
    const url = new URL(req.url);

    // ==========================================
    // FRONTEND UI DASHBOARD
    // ==========================================
    if (url.pathname === "/" && req.method === "GET") {
      const serverUrl = `http://${localIp}:${PORT}`;
      
      const html = `
      <!DOCTYPE html>
      <html lang="en">
      <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>BillEntri Print Server</title>
          <script src="https://cdn.tailwindcss.com"></script>
          <script src="https://cdnjs.cloudflare.com/ajax/libs/qrcodejs/1.0.0/qrcode.min.js"></script>
          <script>
              tailwind.config = {
                  theme: {
                      extend: {
                          colors: { brand: '#016F42' }
                      }
                  }
              }
          </script>
          <style>
              body { background-color: #f3f4f6; }
              #qrcode img { margin: 0 auto; border-radius: 8px; }
          </style>
      </head>
      <body class="min-h-screen flex items-center justify-center p-6">
          <div class="bg-white rounded-2xl shadow-xl max-w-4xl w-full overflow-hidden flex flex-col md:flex-row">
              
              <div class="bg-brand text-white p-10 flex flex-col items-center justify-center md:w-1/3 text-center">
                  <h1 class="text-3xl font-bold mb-2">BillEntri</h1>
                  <p class="text-brand-100 text-sm opacity-90 mb-8">Billing Made Simple</p>
                  
                  <div class="bg-white p-4 rounded-xl shadow-inner mb-6">
                      <div id="qrcode"></div>
                  </div>
                  
                  <p class="font-mono bg-black bg-opacity-20 py-2 px-4 rounded text-sm w-full">
                      ${serverUrl}
                  </p>
                  <p class="text-xs mt-4 opacity-75">Scan from BillEntri App</p>
              </div>

              <div class="p-10 md:w-2/3">
                  <div class="flex items-center space-x-2 mb-6">
                      <svg class="w-6 h-6 text-brand" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"></path></svg>
                      <h2 class="text-2xl font-bold text-gray-800">Printer Setup Guide</h2>
                  </div>
                  
                  <div class="space-y-4">
                      <div class="flex">
                          <div class="flex-shrink-0 flex items-center justify-center w-8 h-8 rounded-full bg-brand text-white font-bold text-sm">1</div>
                          <p class="ml-4 text-gray-600 mt-1"><strong>Connect barcode printer</strong> to your PC via USB.</p>
                      </div>
                      <div class="flex">
                          <div class="flex-shrink-0 flex items-center justify-center w-8 h-8 rounded-full bg-brand text-white font-bold text-sm">2</div>
                          <p class="ml-4 text-gray-600 mt-1">Open <strong>Control Panel</strong> > <strong>Devices and Printers</strong>.</p>
                      </div>
                      <div class="flex">
                          <div class="flex-shrink-0 flex items-center justify-center w-8 h-8 rounded-full bg-brand text-white font-bold text-sm">3</div>
                          <p class="ml-4 text-gray-600 mt-1">Right-click your printer (e.g., TSC TTP-244 Pro) and select <strong>Printer properties</strong>.</p>
                      </div>
                      <div class="flex">
                          <div class="flex-shrink-0 flex items-center justify-center w-8 h-8 rounded-full bg-brand text-white font-bold text-sm">4</div>
                          <p class="ml-4 text-gray-600 mt-1">Go to the <strong>Sharing</strong> tab, check <strong>Share this printer</strong>.</p>
                      </div>
                      <div class="flex">
                          <div class="flex-shrink-0 flex items-center justify-center w-8 h-8 rounded-full bg-brand text-white font-bold text-sm">5</div>
                          <p class="ml-4 text-gray-600 mt-1">Give it the share name <code class="bg-gray-100 px-2 py-1 rounded text-brand font-bold">bacode</code> and click Apply.</p>
                      </div>
                      <div class="flex">
                          <div class="flex-shrink-0 flex items-center justify-center w-8 h-8 rounded-full bg-brand text-white font-bold text-sm">6</div>
                          <p class="ml-4 text-gray-600 mt-1">Scan the QR code on the left using the <strong>BillEntri</strong> app and Save. You can now print directly from the Purchase screen!</p>
                      </div>
                  </div>

                  <div class="mt-8 border-t pt-6 flex items-center text-sm text-gray-500">
                      <svg class="w-5 h-5 mr-2 text-blue-500" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M17.707 9.293a1 1 0 010 1.414l-7 7a1 1 0 01-1.414 0l-7-7A.997.997 0 012 10V5a3 3 0 013-3h5c.256 0 .512.098.707.293l7 7zM5 6a1 1 0 100-2 1 1 0 000 2z" clip-rule="evenodd"></path></svg>
                      Currently Supported on Windows Only
                  </div>
              </div>
          </div>

          <script>
              // Generate the QR Code dynamically based on the server's IP
              new QRCode(document.getElementById("qrcode"), {
                  text: "${serverUrl}",
                  width: 200,
                  height: 200,
                  colorDark : "#016F42",
                  colorLight : "#ffffff",
                  correctLevel : QRCode.CorrectLevel.H
              });
          </script>
      </body>
      </html>
      `;
      return new Response(html, { headers: { "Content-Type": "text/html" } });
    }

    // ==========================================
    // HEALTH CHECK API
    // ==========================================
    if (url.pathname === "/test") {
      return new Response("OK");
    }

    // ==========================================
    // BULK PRINT API
    // ==========================================
    if (url.pathname === "/print-bulk" && req.method === "POST") {
      try {
        const items = (await req.json()) as PrintItem[];

        let tspl = `
SIZE 77.6 mm,25 mm
GAP 3 mm,0
DENSITY 8
SPEED 4
DIRECTION 1
REFERENCE 0,0
`;

        for (let i = 0; i < items.length; i += 2) {
          const left = items[i];
          const right = items[i + 1];

          if (!left) continue;

          tspl += `\nCLS\n`;

          // LEFT LABEL
          const leftCompany = left.companyName.substring(0, 25);
          const [leftName1, leftName2] = splitText(left.itemName, 16);
          const leftPrice = `${left.currency} ${left.price}`;
          
          tspl += `TEXT ${getCenteredX(leftCompany, false, "2")},10,"2",0,1,1,"${leftCompany}"\n`;
          tspl += `BAR 15,35,280,2\n`; 
          tspl += `TEXT 15,45,"3",0,1,1,"${leftName1}"\n`;
          tspl += `TEXT 16,45,"3",0,1,1,"${leftName1}"\n`; 
          
          let leftNextY = 75;
          let leftBarcodeHeight = 55;
          if (leftName2) {
             tspl += `TEXT 15,75,"2",0,1,1,"${leftName2}"\n`;
             leftNextY = 100;
             leftBarcodeHeight = 40;
          }
          tspl += `BARCODE ${LEFT_BARCODE_X},${leftNextY},"128",${leftBarcodeHeight},1,0,2,2,"${left.barcode}"\n`;
          const leftPriceX = getRightAlignedX(leftPrice, false, "3");
          tspl += `TEXT ${leftPriceX},155,"3",0,1,1,"${leftPrice}"\n`;
          tspl += `TEXT ${leftPriceX + 1},155,"3",0,1,1,"${leftPrice}"\n`; 

          // RIGHT LABEL
          if (right) {
            const rightCompany = right.companyName.substring(0, 25);
            const [rightName1, rightName2] = splitText(right.itemName, 16);
            const rightPrice = `${right.currency} ${right.price}`;
            
            tspl += `TEXT ${getCenteredX(rightCompany, true, "2")},10,"2",0,1,1,"${rightCompany}"\n`;
            tspl += `BAR 325,35,280,2\n`; 
            tspl += `TEXT 325,45,"3",0,1,1,"${rightName1}"\n`;
            tspl += `TEXT 326,45,"3",0,1,1,"${rightName1}"\n`; 
            
            let rightNextY = 75;
            let rightBarcodeHeight = 55;
            if (rightName2) {
               tspl += `TEXT 325,75,"2",0,1,1,"${rightName2}"\n`;
               rightNextY = 100;
               rightBarcodeHeight = 40;
            }
            tspl += `BARCODE ${RIGHT_BARCODE_X},${rightNextY},"128",${rightBarcodeHeight},1,0,2,2,"${right.barcode}"\n`;
            const rightPriceX = getRightAlignedX(rightPrice, true, "3");
            tspl += `TEXT ${rightPriceX},155,"3",0,1,1,"${rightPrice}"\n`;
            tspl += `TEXT ${rightPriceX + 1},155,"3",0,1,1,"${rightPrice}"\n`; 
          }

          tspl += `PRINT 1\n`;
        }

        console.log("Printing", items.length, "labels");
        await sendToPrinter(tspl);
        return Response.json({ success: true, printed: items.length });
      } catch (error) {
        console.error(error);
        return Response.json({ success: false, error: String(error) }, { status: 500 });
      }
    }

    return new Response("Not Found", { status: 404 });
  },
});

console.log("=====================================================");
console.log(" BillEntri Print Server Started");
console.log(` Dashboard / Setup : http://${localIp}:${PORT}`);
console.log("=====================================================");