// QR Code generation port for Elm
import QRCode from 'qrcode';

interface QRPorts {
  generateQRCode: { subscribe: (callback: (url: string) => void) => void };
  qrCodeGenerated: { send: (result: { success: boolean; dataUrl?: string; error?: string }) => void };
}

interface ElmAppWithQR {
  ports: QRPorts;
}

export function setupQRPorts(app: ElmAppWithQR): void {
  app.ports.generateQRCode.subscribe(async (url: string) => {
    try {
      const dataUrl = await QRCode.toDataURL(url, {
        width: 256,
        margin: 2,
        errorCorrectionLevel: 'M',
        color: {
          dark: '#000000',
          light: '#FFFFFF'
        }
      });
      app.ports.qrCodeGenerated.send({ success: true, dataUrl: dataUrl });
    } catch (err) {
      console.error('QR generation failed:', err);
      app.ports.qrCodeGenerated.send({
        success: false,
        error: err instanceof Error ? err.message : 'Unknown error'
      });
    }
  });
}
