/**
 * 哈希计算相关的数据模型。
 * 全部使用 class 显式类型，避免 ArkTS 严格模式下的无类型对象字面量。
 */
export class HashResultItem {
  fileName: string = '';
  algo: string = '';
  hashValue: string = '';
  size: number = -1;
  ok: boolean = false;
}

export class HistoryEntry {
  fileName: string = '';
  algo: string = '';
  hashValue: string = '';
  size: number = -1;
  time: number = 0;
}

/** 对比页单个文件槽位 */
export class FileSlot {
  uri: string = '';
  fileName: string = '';
  size: number = -1;
  hashValue: string = '';
  err: boolean = false;
}
