import { hash, fileIo } from '@kit.CoreFileKit';

const TAG = 'HashService';
const CHUNK_SIZE = 1024 * 1024;

/**
 * 文件哈希计算服务。
 * 路径来源：DocumentViewPicker 授权的 URI（file://docs/...）或应用沙箱路径，
 * 不绕过 Picker 直接读取公共目录。
 */
export class HashService {

  /**
   * 计算文件哈希：统一 openSync(uri) 拿 fd 后分块 update。
   * hash.hash 仅接受应用沙箱路径（见 SDK d.ts），不支持 Picker 授权的 file:// URI，
   * 因此不能用它计算 Picker 选中的文件。
   */
  static async computeFileHash(uri: string, algo: string): Promise<string> {
    return HashService.computeStreamedHash(uri, algo);
  }

  /** 流式哈希：openSync 支持 Picker 授权的 file:// URI，逐块读入、及时释放 fd */
  static async computeStreamedHash(uri: string, algo: string): Promise<string> {
    let file: fileIo.File;
    try {
      file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
    } catch (e) {
      console.error(TAG, 'open failed');
      throw new Error('open failed');
    }
    try {
      const hs = hash.createHash(algo);
      const buf = new ArrayBuffer(CHUNK_SIZE);
      let readLen = fileIo.readSync(file.fd, buf);
      while (readLen > 0) {
        hs.update(readLen === CHUNK_SIZE ? buf : buf.slice(0, readLen));
        readLen = fileIo.readSync(file.fd, buf);
      }
      return hs.digest().trim().toUpperCase();
    } finally {
      try {
        fileIo.closeSync(file);
      } catch (e) {
        console.error(TAG, 'close fd failed');
      }
    }
  }

  /** 取文件大小，失败返回 -1 */
  static getFileSize(uri: string): number {
    try {
      return fileIo.statSync(uri).size;
    } catch (e) {
      console.error(TAG, 'stat failed');
      return -1;
    }
  }

  /** file:// URI 转为文件路径（含 %20 等解码） */
  static uriToPath(uri: string): string {
    let p = uri;
    if (p.startsWith('file://')) {
      p = p.substring('file://'.length);
    }
    try {
      return decodeURI(p);
    } catch (e) {
      return p;
    }
  }

  /** 从路径/URI 中提取文件名 */
  static fileNameOf(pathOrUri: string): string {
    const path = HashService.uriToPath(pathOrUri);
    const idx = path.lastIndexOf('/');
    if (idx >= 0 && idx < path.length - 1) {
      return path.substring(idx + 1);
    }
    return path;
  }
}
