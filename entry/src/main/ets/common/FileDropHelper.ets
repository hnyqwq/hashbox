import { unifiedDataChannel, uniformDataStruct, uniformTypeDescriptor } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';

/**
 * 文件拖拽接收器（HarmonyOS 统一拖拽/UDMF 标准通路）。
 * 文件管理器拖出的数据是 general.file-uri 的 FileUri 结构体，且大文件必须走
 * startDataLoading 异步落盘（destUri 指定本应用沙箱目录），不能直接 getData 取值。
 */
export class FileDropHelper {
  /** 从拖拽事件接收文件，完成后以沙箱内文件 URI 列表回调 */
  static receive(event: DragEvent, context: common.Context, onFiles: (uris: string[]) => void): void {
    console.error('FileDropHelper', 'receive called');
    const destDir = context.cacheDir + '/drop';
    try {
      fileIo.mkdirSync(destDir, true);
    } catch (e) {
      // 目录已存在
    }
    const listener: unifiedDataChannel.DataProgressListener =
      (progressInfo: unifiedDataChannel.ProgressInfo, data: unifiedDataChannel.UnifiedData | null) => {
        // progress = -1 表示获取失败；100 表示数据就绪
        if (progressInfo.progress === 100 && data !== null) {
          const uris = FileDropHelper.extract(data);
          if (uris.length > 0) {
            onFiles(uris);
          }
        }
      };
    try {
      const options: unifiedDataChannel.GetDataParams = {
        destUri: fileUri.getUriFromPath(destDir),
        fileConflictOptions: unifiedDataChannel.FileConflictOptions.OVERWRITE,
        progressIndicator: unifiedDataChannel.ProgressIndicator.DEFAULT,
        dataProgressListener: listener
      };
      event.startDataLoading(options);
      console.error('FileDropHelper', 'startDataLoading ok');
    } catch (e) {
      console.error('FileDropHelper', 'startDataLoading failed, fallback to getData');
      // startDataLoading 不可用（如纯文本拖拽数据），退回同步解析
      try {
        const uris = FileDropHelper.extract(event.getData());
        console.error('FileDropHelper', `getData extracted ${uris.length}`);
        if (uris.length > 0) {
          onFiles(uris);
        }
      } catch (err) {
        console.error('FileDropHelper', 'getData fallback failed');
      }
    }
  }

  /** 从 UnifiedData 中提取全部文件 URI（兼容 FILE_URI 结构体与 FILE 字符串两种记录） */
  private static extract(data: unifiedDataChannel.UnifiedData): string[] {
    const out: string[] = [];
    const records = data.getRecords();
    for (const rec of records) {
      const types = rec.getTypes();
      if (types.includes(uniformTypeDescriptor.UniformDataType.FILE_URI)) {
        const entry = rec.getEntry(uniformTypeDescriptor.UniformDataType.FILE_URI);
        if (entry === null || entry === undefined) {
          continue;
        }
        const file = entry as Object as uniformDataStruct.FileUri;
        if (file.oriUri !== undefined && file.oriUri.length > 0) {
          out.push(file.oriUri);
        }
      } else if (types.includes(uniformTypeDescriptor.UniformDataType.FILE)) {
        const value = rec.getValue();
        if (typeof value === 'string' && value.length > 0) {
          out.push(value);
        }
      }
    }
    return out;
  }
}
