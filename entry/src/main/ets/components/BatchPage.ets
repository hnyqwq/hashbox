import { picker, fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { HashService } from '../common/HashService';
import { Prefs, ALGO_CODES } from '../common/Prefs';
import { FormatUtil } from '../common/FormatUtil';
import { HashResultItem } from '../model/HashModels';
import { FileDropHelper } from '../common/FileDropHelper';
import { SegmentButtonV2Items, TabSegmentButtonV2 } from '@kit.ArkUI';

/**
 * 批量页：用户多选文件（最多 100 个）后逐个计算哈希（顺序处理，及时释放 fd），
 * 大文件走 HashStream 流式分批 update；支持中途取消；结果表 + CSV 导出。
 */
@Component
export struct BatchPage {
  scroller: Scroller = new Scroller();
  @State algoIndex: number = 2;
  @State fileUris: string[] = [];
  @State results: HashResultItem[] = [];
  @State running: boolean = false;
  @State doneCount: number = 0;
  @State totalCount: number = 0;
  @State finished: boolean = false;
  @State errText: string = '';
  @StorageLink('sizeUnit') sizeUnit: string = 'auto';
  @StorageProp('isWide') isWide: boolean = false;

  private resManager: common.Context | undefined = undefined;

  private algoItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: 'MD5' },
    { text: 'SHA1' },
    { text: 'SHA256' }
  ]);
  private cancelFlag: boolean = false;

  aboutToAppear(): void {
    this.resManager = getContext(this) as common.Context;
    const def = AppStorage.get<string>('defaultAlgo');
    const idx = ALGO_CODES.indexOf(def === undefined ? 'sha256' : def);
    if (idx >= 0) {
      this.algoIndex = idx;
    }
  }

  private str(res: Resource, arg1?: number | string, arg2?: number | string): string {
    if (this.resManager === undefined) {
      return '';
    }
    if (arg1 !== undefined && arg2 !== undefined) {
      return this.resManager.resourceManager.getStringSync(res, arg1, arg2);
    }
    if (arg1 !== undefined) {
      return this.resManager.resourceManager.getStringSync(res, arg1);
    }
    return this.resManager.resourceManager.getStringSync(res);
  }

  private toast(msg: string): void {
    this.getUIContext().getPromptAction().showToast({ message: msg, duration: 2000 });
  }

  private copyResult(value: string): void {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, value);
      pasteboard.getSystemPasteboard().setDataSync(data);
      this.toast(this.str($r('app.string.copied')));
    } catch (e) {
      console.error('copy failed');
    }
  }

  /** 拖拽落点：UDMF startDataLoading 异步落盘后回调文件 URI 列表 */
  private onDropFiles(event: DragEvent): void {
    FileDropHelper.receive(event, getContext(this) as common.Context, (uris: string[]) => {
      if (uris.length > 0) {
        this.fileUris = uris;
        this.results = [];
        this.finished = false;
        this.errText = '';
      }
    });
  }

  /** 多选文件：Picker 授权返回 file:// URI，直接用于 hash/openSync，无需剥 scheme */
  private async pickFiles(): Promise<void> {
    try {
      const docPicker = new picker.DocumentViewPicker(getContext(this) as common.Context);
      const opts = new picker.DocumentSelectOptions();
      opts.maxSelectNumber = 100;
      const uris: string[] = await docPicker.select(opts);
      if (uris === undefined || uris === null || uris.length === 0) {
        return;
      }
      this.fileUris = uris;
      this.results = [];
      this.finished = false;
      this.errText = '';
    } catch (e) {
      console.error('pickFiles failed');
    }
  }

  /** 顺序遍历计算：逐个文件处理、及时释放 fd，避免并发打开过多文件描述符 */
  private async runBatch(): Promise<void> {
    if (this.running || this.fileUris.length === 0) {
      return;
    }
    this.running = true;
    this.finished = false;
    this.errText = '';
    this.doneCount = 0;
    this.totalCount = this.fileUris.length;
    this.results = [];
    this.cancelFlag = false;
    const algo = ALGO_CODES[this.algoIndex];
    const acc: HashResultItem[] = [];
    try {
      for (const uri of this.fileUris) {
        if (this.cancelFlag) {
          break;
        }
        const item = new HashResultItem();
        item.fileName = HashService.fileNameOf(uri);
        item.algo = algo;
        item.size = HashService.getFileSize(uri);
        try {
          item.hashValue = await HashService.computeFileHash(uri, algo);
          item.ok = true;
        } catch (e) {
          item.hashValue = '';
          item.ok = false;
        }
        acc.push(item);
        this.results = acc.slice(); // 拷贝触发刷新
        this.doneCount = acc.length;
      }
      if (this.cancelFlag) {
        this.toast(this.str($r('app.string.batch_cancelled')));
      } else {
        this.finished = true;
        this.toast(this.str($r('app.string.batch_done'), this.doneCount));
      }
    } catch (e) {
      this.errText = this.str($r('app.string.error_hash'));
    } finally {
      this.running = false;
    }
  }

  private cancelBatch(): void {
    this.cancelFlag = true;
  }

  /** 导出 CSV：DocumentViewPicker.save + fileIo 写入 */
  private async exportCsv(): Promise<void> {
    if (this.results.length === 0) {
      return;
    }
    try {
      const docPicker = new picker.DocumentViewPicker(getContext(this) as common.Context);
      const opts = new picker.DocumentSaveOptions();
      opts.newFileNames = ['hashbox_results.csv'];
      const uris: string[] = await docPicker.save(opts);
      if (uris === undefined || uris === null || uris.length === 0) {
        this.toast(this.str($r('app.string.batch_export_cancel')));
        return;
      }
      const file = fileIo.openSync(uris[0],
        fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(file.fd, FormatUtil.buildCsv(this.results));
      } finally {
        try {
          fileIo.closeSync(file);
        } catch (e) {
          console.error('close failed');
        }
      }
      this.toast(this.str($r('app.string.batch_export_done')));
    } catch (e) {
      console.error('export csv failed');
      this.errText = this.str($r('app.string.error_hash'));
    }
  }

  @Builder
  inputGroup() {
    // 文件多选 + 算法：虚线拖入区，支持点击选择或拖拽文件
    Column() {
      Text(this.fileUris.length === 0 ?
        this.str($r('app.string.drop_zone_hint')) :
        this.str($r('app.string.batch_selected_count'), this.fileUris.length))
        .fontSize(14)
        .fontColor(this.fileUris.length === 0 ? $r('app.color.text_secondary') : $r('app.color.text_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.MARQUEE })
        .width('100%')
        .textAlign(TextAlign.Center)

      Button(this.str($r('app.string.batch_select_files')))
        .height(36)
        .fontSize(13)
        .margin({ top: 10 })
        .backgroundColor($r('app.color.chip_bg'))
        .fontColor($r('app.color.primary_color'))
        .onClick(() => {
          this.pickFiles();
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
      this.onDropFiles(event);
    }, { disableDataPrefetch: true })

    // 算法选择（与对比页一致的分段按钮）
    TabSegmentButtonV2({
      items: this.algoItems,
      selectedIndex: this.algoIndex,
      $selectedIndex: (index: number) => {
        this.algoIndex = index;
      },
      enableStateAnimation: true
    })
    .width('100%')
    .margin({ top: 12 })

    // 操作行
    Row({ space: 8 }) {
      Button(this.running ? this.str($r('app.string.computing')) : this.str($r('app.string.batch_start')))
        .enabled(!this.running && this.fileUris.length > 0)
        .layoutWeight(1)
        .height(40)
        .fontSize(14)
        .backgroundColor(this.running || this.fileUris.length === 0 ?
          $r('app.color.disabled_bg') : $r('app.color.primary_color'))
        .fontColor(this.running || this.fileUris.length === 0 ?
          $r('app.color.text_tertiary') : $r('app.color.card_color'))
        .onClick(() => {
          this.runBatch();
        })

      Button(this.str($r('app.string.cancel')))
        .enabled(this.running)
        .layoutWeight(1)
        .height(40)
        .fontSize(14)
        .backgroundColor(this.running ? $r('app.color.primary_color') : $r('app.color.disabled_bg'))
        .fontColor(this.running ? $r('app.color.card_color') : $r('app.color.text_tertiary'))
        .onClick(() => {
          this.cancelBatch();
        })

      Button(this.str($r('app.string.batch_export')))
        .enabled(this.results.length > 0 && !this.running)
        .layoutWeight(1)
        .height(40)
        .fontSize(14)
        .backgroundColor(this.results.length > 0 && !this.running ?
          $r('app.color.primary_color') : $r('app.color.disabled_bg'))
        .fontColor(this.results.length > 0 && !this.running ?
          $r('app.color.card_color') : $r('app.color.text_tertiary'))
        .onClick(() => {
          this.exportCsv();
        })
    }
    .width('100%')
    .margin({ top: 12 })

    if (this.errText !== '') {
      Text(this.errText)
        .fontSize(14)
        .fontColor($r('app.color.danger_color'))
        .margin({ top: 12 })
        .alignSelf(ItemAlign.Start)
    }

    if (this.totalCount > 0) {
      Text(this.running ?
        this.str($r('app.string.batch_progress'), this.doneCount, this.totalCount) :
        this.str($r('app.string.batch_done'), this.doneCount))
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: 12 })
        .alignSelf(ItemAlign.Start)
    }
  }

  @Builder
  resultGroup() {
    // 结果表
    Column() {
      Row() {
        Text(this.str($r('app.string.file_name')))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_secondary'))
          .layoutWeight(1)
        Text(this.str($r('app.string.algorithm')))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_secondary'))
          .width(64)
        Text(this.str($r('app.string.file_size')))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_secondary'))
          .width(72)
          .textAlign(TextAlign.End)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })

      Divider().color($r('app.color.divider_color'))

      List() {
        ForEach(this.results, (item: HashResultItem, index: number) => {
          ListItem() {
            Column() {
              Row() {
                Text(item.fileName)
                  .fontSize(13)
                  .fontColor($r('app.color.text_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.MARQUEE })
                  .layoutWeight(1)
                Text(item.ok ? item.algo.toUpperCase() : '-')
                  .fontSize(13)
                  .fontColor($r('app.color.text_secondary'))
                  .width(64)
                Text(FormatUtil.formatSize(item.size, this.sizeUnit))
                  .fontSize(13)
                  .fontColor($r('app.color.text_secondary'))
                  .width(72)
                  .textAlign(TextAlign.End)
              }
              .width('100%')

              Row() {
                Text(item.ok ? item.hashValue : this.str($r('app.string.error_hash')))
                  .fontSize(11)
                  .fontFamily('monospace')
                  .fontColor(item.ok ? $r('app.color.hash_text_color') : $r('app.color.danger_color'))
                  .copyOption(CopyOptions.LocalDevice)
                  .layoutWeight(1)
                  .textAlign(TextAlign.Start)
                if (item.ok) {
                  Button(this.str($r('app.string.copy')))
                    .height(26)
                    .fontSize(11)
                    .padding({ left: 10, right: 10 })
                    .margin({ left: 8 })
                    .backgroundColor($r('app.color.chip_bg'))
                    .fontColor($r('app.color.primary_color'))
                    .onClick(() => {
                      this.copyResult(item.hashValue);
                    })
                }
              }
              .width('100%')
              .margin({ top: 4 })
            }
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          }
        }, (item: HashResultItem, index: number) => `${index}_${item.fileName}`)
      }
      .width('100%')
      .height(Math.min(this.results.length * 88 + 10, 320))
    }
    .borderRadius(16)
    .backgroundColor($r('app.color.card_color'))
    .width('100%')
    .margin({ top: this.isWide ? 0 : 12 })
    .visibility(this.results.length > 0 ? Visibility.Visible : Visibility.None)

    if (this.results.length === 0 && this.isWide) {
      // 宽屏右栏空态：居中提示
      Text(this.str($r('app.string.result_empty')))
        .fontSize(13)
        .fontColor($r('app.color.text_tertiary'))
        .margin({ top: 24 })
        .width('100%')
        .textAlign(TextAlign.Center)
    }
  }

  build() {
    Scroll(this.scroller) {
      Column() {
        if (this.isWide) {
          Row({ space: 12 }) {
            Column() {
              this.inputGroup()
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Column() {
              this.resultGroup()
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
        } else {
          Column() {
            this.inputGroup()
            this.resultGroup()
          }
          .width('100%')
        }

        Text('').height(24)
      }
      .padding({ left: 16, right: 16, top: 110, bottom: 110 })
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }
}
