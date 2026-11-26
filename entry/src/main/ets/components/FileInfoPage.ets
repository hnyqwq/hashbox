import { common } from '@kit.AbilityKit';
import { fileIo, picker } from '@kit.CoreFileKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { HashService } from '../common/HashService';
import { ALGO_CODES } from '../common/Prefs';
import { FileDropHelper } from '../common/FileDropHelper';
import { FormatUtil } from '../common/FormatUtil';

/** 文件信息页的单条哈希展示行 */
class HashRow {
  algo: string = '';
  value: string = '';
  failed: boolean = false;
}

/**
 * 文件信息页（底部第 4 个 Tab）：
 * 选择/拖入/外部"打开方式"进入后，展示文件的大小、修改时间、类型与路径。
 */
@Component
export struct FileInfoPage {
  scroller: Scroller = new Scroller();
  @StorageProp('isWide') isWide: boolean = false;
  @StorageProp('openedFileUri') @Watch('onOpenedUri') openedFileUri: string = '';
  @State fileName: string = '';
  @State fileUri: string = '';
  @State fileSize: number = -1;
  @State modifiedText: string = '';
  @State extText: string = '';
  @State loaded: boolean = false;
  @State hashRows: HashRow[] = [];
  @StorageLink('sizeUnit') sizeUnit: string = 'auto';

  private resManager: common.Context | undefined = undefined;

  aboutToAppear(): void {
    this.resManager = getContext(this) as common.Context;
    if (this.openedFileUri !== '') {
      this.applyFile(this.openedFileUri);
    }
  }

  private onOpenedUri(): void {
    if (this.openedFileUri !== '') {
      this.applyFile(this.openedFileUri);
    }
  }

  private str(res: Resource): string {
    if (this.resManager === undefined) {
      return '';
    }
    return this.resManager.resourceManager.getStringSync(res);
  }

  private toast(msg: string): void {
    this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2000 });
  }

  private applyFile(uri: string): void {
    this.fileUri = uri;
    this.fileName = HashService.fileNameOf(uri);
    this.fileSize = -1;
    this.modifiedText = '';
    this.extText = '';
    this.loaded = false;
    console.error('FileInfoPage', 'applyFile uri=' + uri);
    try {
      const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      try {
        const stat = fileIo.statSync(file.fd);
        this.fileSize = stat.size;
        this.modifiedText = FormatUtil.formatTime(stat.mtime);
      } finally {
        try {
          fileIo.closeSync(file);
        } catch (e) {
          console.error('close failed');
        }
      }
    } catch (e) {
      console.error('stat failed');
    }
    const idx = this.fileName.lastIndexOf('.');
    this.extText = idx >= 0 ? this.fileName.substring(idx + 1).toUpperCase() : '';
    this.loaded = true;
    this.computeAllHashes();
  }

  /** 顺序计算 MD5/SHA1/SHA256，逐条完成后刷新（换文件后丢弃过期结果） */
  private computeAllHashes(): void {
    const rows: HashRow[] = [];
    for (const algo of ALGO_CODES) {
      const row = new HashRow();
      row.algo = algo;
      rows.push(row);
    }
    this.hashRows = rows;
    const targetUri = this.fileUri;
    const run = (index: number): void => {
      if (index >= ALGO_CODES.length || targetUri !== this.fileUri) {
        return;
      }
      const algo = ALGO_CODES[index];
      HashService.computeFileHash(targetUri, algo).then((value: string) => {
        this.updateRow(index, value, false);
        run(index + 1);
      }).catch(() => {
        this.updateRow(index, '', true);
        run(index + 1);
      });
    };
    run(0);
  }

  private updateRow(index: number, value: string, failed: boolean): void {
    const next = this.hashRows.slice();
    next[index] = { algo: ALGO_CODES[index], value: value, failed: failed };
    this.hashRows = next;
  }

  private copyValue(value: string): void {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, value);
      pasteboard.getSystemPasteboard().setDataSync(data);
      this.toast(this.str($r('app.string.copied')));
    } catch (e) {
      console.error('copy failed');
    }
  }

  build() {
    Scroll(this.scroller) {
      Column() {
        // 虚线拖入区：点击选择或拖入文件
        Column() {
          Text(this.fileName === '' ?
            (this.isWide ? this.str($r('app.string.drop_zone_hint')) :
              this.str($r('app.string.drop_zone_hint_phone'))) : this.fileName)
            .fontSize(this.fileName === '' ? 15 : 14)
            .fontWeight(this.fileName === '' ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.fileName === '' ? $r('app.color.text_secondary') : $r('app.color.text_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.MARQUEE })
            .width('100%')
            .textAlign(TextAlign.Center)
          if (this.fileSize >= 0) {
            Text(FormatUtil.formatSize(this.fileSize, this.sizeUnit))
              .fontSize(12)
              .fontColor($r('app.color.text_secondary'))
              .margin({ top: 4 })
          }
          Button(this.str($r('app.string.select_file')))
            .height(36)
            .fontSize(13)
            .margin({ top: 10 })
            .backgroundColor($r('app.color.chip_bg'))
            .fontColor($r('app.color.primary_color'))
            .onClick(() => {
              this.pickFile();
            })
        }
        .alignItems(HorizontalAlign.Center)
        .padding(20)
        .borderRadius(16)
        .border({
          width: 1.5,
          style: BorderStyle.Dashed,
          color: $r('app.color.divider_color')
        })
        .backgroundColor($r('app.color.card_color'))
        .width('100%')
        .allowDrop([utd.UniformDataType.FILE, utd.UniformDataType.FILE_URI])
        .onDrop((event: DragEvent) => {
          FileDropHelper.receive(event, getContext(this) as common.Context, (uris: string[]) => {
            if (uris.length > 0) {
              this.applyFile(uris[0]);
            }
          });
        })

        // 信息卡片
        if (this.loaded) {
          Column() {
            this.infoRow(this.str($r('app.string.info_size')),
              this.fileSize >= 0 ? FormatUtil.formatSize(this.fileSize, this.sizeUnit) : '-')
            Divider().color($r('app.color.divider_color'))
            this.infoRow(this.str($r('app.string.info_type')),
              this.extText === '' ? '-' : this.extText)
            Divider().color($r('app.color.divider_color'))
            this.infoRow(this.str($r('app.string.info_modified')),
              this.modifiedText === '' ? '-' : this.modifiedText)
            Divider().color($r('app.color.divider_color'))
            this.infoRow(this.str($r('app.string.info_path')), this.fileUri)

            // 三种算法哈希值
            Divider().color($r('app.color.divider_color'))
            ForEach(this.hashRows, (row: HashRow) => {
              Row() {
                Text(row.algo.toUpperCase())
                  .fontSize(13)
                  .fontColor($r('app.color.text_secondary'))
                  .width(72)
                if (row.failed) {
                  Text(this.str($r('app.string.error_hash')))
                    .fontSize(12)
                    .fontColor($r('app.color.danger_color'))
                    .layoutWeight(1)
                } else if (row.value === '') {
                  LoadingProgress()
                    .width(16)
                    .height(16)
                    .color($r('app.color.primary_color'))
                    .layoutWeight(1)
                } else {
                  Text(row.value)
                    .fontSize(12)
                    .fontFamily('monospace')
                    .fontColor($r('app.color.hash_text_color'))
                    .copyOption(CopyOptions.LocalDevice)
                    .maxLines(2)
                    .layoutWeight(1)
                  Button(this.str($r('app.string.copy')))
                    .height(26)
                    .fontSize(11)
                    .padding({ left: 10, right: 10 })
                    .margin({ left: 8 })
                    .backgroundColor($r('app.color.chip_bg'))
                    .fontColor($r('app.color.primary_color'))
                    .onClick(() => {
                      this.copyValue(row.value);
                    })
                }
              }
              .width('100%')
              .padding({ top: 10, bottom: 10 })
              .alignItems(VerticalAlign.Top)
            })
          }
          .padding(16)
          .borderRadius(16)
          .backgroundColor($r('app.color.card_color'))
          .width('100%')
          .margin({ top: 12 })
        }

        Text('')
          .height(24)
      }
      .padding({ left: 16, right: 16, top: 110, bottom: 110 })
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }

  private async pickFile(): Promise<void> {
    try {
      const docPicker = new picker.DocumentViewPicker(getContext(this) as common.Context);
      const opts = new picker.DocumentSelectOptions();
      opts.maxSelectNumber = 1;
      const uris: string[] = await docPicker.select(opts);
      if (uris === undefined || uris === null || uris.length === 0) {
        return;
      }
      this.applyFile(uris[0]);
    } catch (e) {
      console.error('pickFile failed');
    }
  }

  @Builder
  infoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .width(72)
      Text(value)
        .fontSize(13)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .alignItems(VerticalAlign.Top)
  }
}
