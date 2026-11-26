import { picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { HashService } from '../common/HashService';
import { Prefs, ALGO_CODES } from '../common/Prefs';
import { FormatUtil } from '../common/FormatUtil';
import { HistoryEntry } from '../model/HashModels';
import { HistoryPanel } from './HistoryPanel';
import { FileDropHelper } from '../common/FileDropHelper';
import { SegmentButtonV2Items, TabSegmentButtonV2 } from '@kit.ArkUI';

/**
 * 校验页：单文件哈希计算 + 一键复制。
 */
@Component
export struct VerifyPage {
  scroller: Scroller = new Scroller();
  @State algoIndex: number = 2;
  @State fileName: string = '';
  @State fileUri: string = '';
  @State fileSize: number = -1;
  @State result: string = '';
  @State busy: boolean = false;
  @State errText: string = '';
  @StorageLink('sizeUnit') sizeUnit: string = 'auto';
  @StorageProp('isWide') isWide: boolean = false;

  private resManager: common.Context | undefined = undefined;

  private algoItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: 'MD5' },
    { text: 'SHA1' },
    { text: 'SHA256' }
  ]);

  aboutToAppear(): void {
    this.resManager = getContext(this) as common.Context;
    const def = AppStorage.get<string>('defaultAlgo');
    const idx = ALGO_CODES.indexOf(def === undefined ? 'sha256' : def);
    if (idx >= 0) {
      this.algoIndex = idx;
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

  /** 拖拽落点：UDMF startDataLoading 异步落盘后回调文件 URI */
  private onDropFile(event: DragEvent): void {
    FileDropHelper.receive(event, getContext(this) as common.Context, (uris: string[]) => {
      this.applyFile(uris[0]);
    });
  }

  private applyFile(uri: string): void {
    this.fileUri = uri;
    this.fileName = HashService.fileNameOf(uri);
    this.fileSize = HashService.getFileSize(uri);
    this.result = '';
    this.errText = '';
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
      this.fileUri = uris[0];
      this.fileName = HashService.fileNameOf(this.fileUri);
      this.fileSize = HashService.getFileSize(this.fileUri);
      this.result = '';
      this.errText = '';
    } catch (e) {
      console.error('pickFile failed');
    }
  }

  private async compute(): Promise<void> {
    if (this.fileUri === '' || this.busy) {
      return;
    }
    this.busy = true;
    this.errText = '';
    try {
      const algo = ALGO_CODES[this.algoIndex];
      const value = await HashService.computeFileHash(this.fileUri, algo);
      this.result = value;
      const entry = new HistoryEntry();
      entry.fileName = this.fileName;
      entry.algo = algo;
      entry.hashValue = value;
      entry.size = this.fileSize;
      entry.time = Date.now();
      await Prefs.addHistory(entry);
      this.toast(this.str($r('app.string.history_added')));
    } catch (e) {
      this.result = '';
      this.errText = this.str($r('app.string.error_hash'));
    } finally {
      this.busy = false;
    }
  }

  private async copyResult(): Promise<void> {
    if (this.result === '') {
      return;
    }
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.result);
      pasteboard.getSystemPasteboard().setDataSync(data);
      this.toast(this.str($r('app.string.copied')));
    } catch (e) {
      console.error('copy failed');
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

        Text('')
          .height(8)

        // 历史记录：直接外显在第一页底部
        HistoryPanel()
      }
      .padding({ left: 16, right: 16, top: 110, bottom: 110 })
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }

  @Builder
  inputGroup() {
    // 文件选择卡片：虚线拖入区，支持点击选择或拖拽文件
    Column() {
      Text(this.fileName === '' ? this.str($r('app.string.drop_zone_hint')) : this.fileName)
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
      this.onDropFile(event);
    }, { disableDataPrefetch: true })

    // 算法选择
    Column() {
      Text(this.str($r('app.string.algorithm')))
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_primary'))
        .alignSelf(ItemAlign.Start)
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
    }
    .alignItems(HorizontalAlign.Center)
    .padding(16)
    .borderRadius(16)
    .backgroundColor($r('app.color.card_color'))
    .width('100%')
    .margin({ top: 12 })

    // 计算按钮
    Button(this.busy ? this.str($r('app.string.computing')) : this.str($r('app.string.compute')))
      .enabled(!this.busy && this.fileUri !== '')
      .width('100%')
      .height(44)
      .margin({ top: 16 })
      .backgroundColor(this.busy || this.fileUri === '' ? $r('app.color.disabled_bg') : $r('app.color.primary_color'))
      .fontColor(this.busy || this.fileUri === '' ? $r('app.color.text_tertiary') : $r('app.color.card_color'))
      .onClick(() => {
        this.compute();
      })
  }

  @Builder
  resultGroup() {
    if (this.errText !== '') {
      Text(this.errText)
        .fontSize(14)
        .fontColor($r('app.color.danger_color'))
        .margin({ top: this.isWide ? 0 : 16 })
        .alignSelf(ItemAlign.Start)
    }

    // 结果卡片
    if (this.result !== '') {
      Column() {
        Text(this.result)
          .fontSize(14)
          .fontFamily('monospace')
          .fontColor($r('app.color.hash_text_color'))
          .copyOption(CopyOptions.LocalDevice)
          .textAlign(TextAlign.Start)
          .width('100%')
        Button(this.str($r('app.string.copy')))
          .width('100%')
          .height(40)
          .margin({ top: 12 })
          .backgroundColor($r('app.color.primary_color'))
          .onClick(() => {
            this.copyResult();
          })
      }
      .padding(16)
      .borderRadius(16)
      .backgroundColor($r('app.color.card_color'))
      .width('100%')
      .margin({ top: this.isWide ? 0 : 16 })
    } else {
      Text(this.str($r('app.string.result_empty')))
        .fontSize(13)
        .fontColor($r('app.color.text_tertiary'))
        .margin({ top: 24 })
        .width('100%')
        .textAlign(this.isWide ? TextAlign.Center : TextAlign.Start)
    }
  }
}
