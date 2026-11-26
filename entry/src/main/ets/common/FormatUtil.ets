import { HashResultItem } from '../model/HashModels';

/** 格式化与 CSV 构建工具 */
export class FormatUtil {
  /**
   * 文件大小格式化。unit: auto（自动选档）/ b / kb / mb
   */
  static formatSize(bytes: number, unit: string): string {
    if (bytes < 0) {
      return '-';
    }
    if (unit === 'b') {
      return `${bytes} B`;
    }
    if (unit === 'kb') {
      return `${(bytes / 1024).toFixed(2)} KB`;
    }
    if (unit === 'mb') {
      return `${(bytes / 1048576).toFixed(2)} MB`;
    }
    // auto
    if (bytes < 1024) {
      return `${bytes} B`;
    }
    if (bytes < 1048576) {
      return `${(bytes / 1024).toFixed(2)} KB`;
    }
    if (bytes < 1073741824) {
      return `${(bytes / 1048576).toFixed(2)} MB`;
    }
    return `${(bytes / 1073741824).toFixed(2)} GB`;
  }

  /** 时间戳格式化为 YYYY-MM-DD HH:mm（入参兼容秒/毫秒） */
  static formatTime(stamp: number): string {
    if (stamp <= 0) {
      return '-';
    }
    const ms = stamp < 1e12 ? stamp * 1000 : stamp;
    const d = new Date(ms);
    const p = (n: number): string => n < 10 ? '0' + n : '' + n;
    return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`;
  }

  /** CSV 单元格转义：含引号/逗号/换行时用双引号包裹 */
  static csvCell(value: string): string {
    if (value.indexOf('"') >= 0 || value.indexOf(',') >= 0 || value.indexOf('\n') >= 0) {
      return '"' + value.split('"').join('""') + '"';
    }
    return value;
  }

  /** 结果列表 → CSV 文本（含表头） */
  static buildCsv(rows: HashResultItem[]): string {
    const lines: string[] = [];
    lines.push('File Name,Algorithm,Hash Value,Size(Bytes),Status');
    for (const r of rows) {
      const status = r.ok ? 'OK' : 'FAILED';
      lines.push(
        `${FormatUtil.csvCell(r.fileName)},${FormatUtil.csvCell(r.algo)},${FormatUtil.csvCell(r.hashValue)},` +
        `${r.size},${status}`);
    }
    return lines.join('\n') + '\n';
  }
}
