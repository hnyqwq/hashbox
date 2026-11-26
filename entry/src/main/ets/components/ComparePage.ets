import { picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { uniformTypeDescriptor as utd } from '@kit.ArkData';
import { scanBarcode, scanCore } from '@kit.ScanKit';
import { FileDropHelper } from '../common/FileDropHelper';
import { SegmentButtonV2Items, TabSegmentButtonV2 } from '@kit.ArkUI';
import { HashService } from '../common/HashService';
import { ALGO_CODES } from '../common/Prefs';
import { FormatUtil } from '../common/FormatUtil';
import { FileSlot } from '../model/HashModels';

/** slotCard 按引用传递的参数容器（ArkTS 要求字面量对应显式声明的类） */
export class SlotCardParams {
  slot: FileSlot = new FileSlot();
  target: number = 0;
}

/**
 * 对比页：双文件并行哈希对比 + 剪贴板粘贴哈希值比对。
 */
@Component
export struct ComparePage {
  scroller: Scroller = new Scroller();
  @State slotA: FileSlot = new FileSlot();
  @State slotB: FileSlot = new FileSlot();
  @State algoIndex: number = 2;
  @State pastedHash: string = '';
  @State busy: boolean = false;
  @State compareText: string = '';
  @State compareSame: boolean = false;
  @State compareVisible: boolean = false;
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

  /** 拖拽落点：UDMF startDataLoading 异步落盘后填入对应槽位 */
  private onDropSlot(event: DragEvent, target: number): void {
    FileDropHelper.receive(event, getContext(this) as common.Context, (uris: string[]) => {
      if (uris.length === 0) {
        return;
      }
      const uri = uris[0];
      const slot = new FileSlot();
      slot.uri = uri;
      slot.fileName = HashService.fileNameOf(uri);
      slot.size = HashService.getFileSize(uri);
      slot.err = false;
      if (target === 0) {
        this.slotA = slot;
      } else {
        this.slotB = slot;
      }
      this.compareVisible = false;
    });
  }

  private async pickFile(target: number): Promise<void> {
    try {
      const docPicker = new picker.DocumentViewPicker(getContext(this) as common.Context);
      const opts = new picker.DocumentSelectOptions();
      opts.maxSelectNumber = 1;
      const uris: string[] = await docPicker.select(opts);
      if (uris === undefined || uris === null || uris.length === 0) {
        return;
      }
      const slot = new FileSlot();
      slot.uri = uris[0];
      slot.fileName = HashService.fileNameOf(slot.uri);
      slot.size = HashService.getFileSize(slot.uri);
      slot.err = false;
      if (target === 0) {
        this.slotA = slot;
      } else {
        this.slotB = slot;
      }
      this.compareVisible = false;
    } catch (e) {
      console.error('pickFile failed');
    }
  }

  /** 定义粘贴按钮点击回调，处理授权结果和错误信息 */
  private handlePasteButtonClick: PasteButtonCallback =
    (event: ClickEvent, result: PasteButtonOnClickResult, error?: BusinessError<void>) => {
      if (result === PasteButtonOnClickResult.SUCCESS) {
        this.pasteFromClipboard();
      } else {
        console.error(`paste auth failed. Code: ${error?.code}, message: ${error?.message}`);
      }
    };

  private async pasteFromClipboard(): Promise<void> {
    try {
      const data = pasteboard.getSystemPasteboard().getDataSync();
      if (data === undefined) {
        return;
      }
      const text = data.getPrimaryText();
      if (text !== undefined && text.length > 0) {
        this.pastedHash = text.trim();
      }
    } catch (e) {
      console.error('read clipboard failed');
    }
  }

  /** 扫码读取期望哈希：调用系统级扫码（Scan Kit 默认界面，免权限），读入后立即比对 */
  private async scanExpected(): Promise<void> {
    try {
      const options: scanBarcode.ScanOptions = {
        scanTypes: [scanCore.ScanType.QR_CODE]
      };
      const result = await scanBarcode.startScanForResult(getContext(this) as common.Context, options);
      const text = result.originalValue.trim();
      if (text.length > 0) {
        this.pastedHash = text;
        this.evaluate();
      }
    } catch (e) {
      console.error('scan failed');
    }
  }

  /** 计算单个槽位哈希。以新建对象方式回写，保证 @State 触发刷新 */
  private async computeOne(target: number): Promise<void> {
    const src = target === 0 ? this.slotA : this.slotB;
    try {
      const algo = ALGO_CODES[this.algoIndex];
      const value = await HashService.computeFileHash(src.uri, algo);
      const updated = new FileSlot();
      updated.uri = src.uri;
      updated.fileName = src.fileName;
      updated.size = src.size;
      updated.hashValue = value;
      updated.err = false;
      if (target === 0) {
        this.slotA = updated;
      } else {
        this.slotB = updated;
      }
    } catch (e) {
      const failed = new FileSlot();
      failed.uri = src.uri;
      failed.fileName = src.fileName;
      failed.size = src.size;
      failed.hashValue = '';
      failed.err = true;
      if (target === 0) {
        this.slotA = failed;
      } else {
        this.slotB = failed;
      }
      throw new Error('hash compute failed');
    }
  }

  /** 并行计算两个文件的哈希并对比 */
  private async computeAndCompare(): Promise<void> {
    if (this.busy || (this.slotA.uri === '' && this.slotB.uri === '')) {
      return;
    }
    this.busy = true;
    try {
      const jobs: Promise<void>[] = [];
      if (this.slotA.uri !== '') {
        jobs.push(this.computeOne(0));
      }
      if (this.slotB.uri !== '') {
        jobs.push(this.computeOne(1));
      }
      await Promise.all(jobs);
      this.evaluate();
    } catch (e) {
      this.compareVisible = true;
      this.compareSame = false;
      this.compareText = this.str($r('app.string.error_hash'));
    } finally {
      this.busy = false;
    }
  }

  /** 对比：文件间对比，或单文件 vs 粘贴的哈希值。统一大小写后比较 */
  private evaluate(): void {
    this.compareVisible = true;
    const computed: string[] = [];
    if (this.slotA.uri !== '' && this.slotA.hashValue !== '' && !this.slotA.err) {
      computed.push(this.slotA.hashValue.toUpperCase());
    }
    if (this.slotB.uri !== '' && this.slotB.hashValue !== '' && !this.slotB.err) {
      computed.push(this.slotB.hashValue.toUpperCase());
    }
    if (this.pastedHash.trim().length > 0) {
      computed.push(this.pastedHash.trim().toUpperCase());
    }
    if (computed.length < 2) {
      this.compareSame = false;
      this.compareText = this.str($r('app.string.compare_need_input'));
      return;
    }
    const first = computed[0];
    const bothFilesOnly =
      this.slotA.hashValue !== '' && this.slotB.hashValue !== '' && this.pastedHash.trim() === '';
    for (let i = 1; i < computed.length; i++) {
      if (computed[i] !== first) {
        this.compareSame = false;
        this.compareText = bothFilesOnly ?
          this.str($r('app.string.compare_files_diff')) :
          this.str($r('app.string.compare_diff'));
        return;
      }
    }
    this.compareSame = true;
    this.compareText = bothFilesOnly ?
      this.str($r('app.string.compare_files_same')) :
      this.str($r('app.string.compare_same'));
  }

  @Builder
  slotCard($$: SlotCardParams) {
    Column() {
      Row() {
        Text($$.slot.fileName === '' ?
          this.str($r('app.string.drop_zone_hint')) : $$.slot.fileName)
          .fontSize(14)
          .fontColor($$.slot.fileName === '' ? $r('app.color.text_tertiary') : $r('app.color.text_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.MARQUEE })
          .layoutWeight(1)
        if ($$.slot.size >= 0) {
          Text(FormatUtil.formatSize($$.slot.size, this.sizeUnit))
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
            .margin({ left: 8 })
        }
      }
      .width('100%')

      if ($$.slot.hashValue !== '' && !$$.slot.err) {
        Text($$.slot.hashValue)
          .fontSize(12)
          .fontFamily('monospace')
          .fontColor($r('app.color.hash_text_color'))
          .copyOption(CopyOptions.LocalDevice)
          .width('100%')
          .margin({ top: 8 })
      }
      if ($$.slot.err) {
        Text(this.str($r('app.string.error_hash')))
          .fontSize(12)
          .fontColor($r('app.color.danger_color'))
          .margin({ top: 8 })
      }

      Button($$.target === 0 ? this.str($r('app.string.select_file_a')) :
        this.str($r('app.string.select_file_b')))
        .width('100%')
        .height(36)
        .fontSize(13)
        .margin({ top: 12 })
        .backgroundColor($r('app.color.chip_bg'))
        .fontColor($r('app.color.primary_color'))
        .onClick(() => {
          this.pickFile($$.target);
        })
    }
    .padding(16)
    .borderRadius(16)
    .border({
      width: 1.5,
      style: BorderStyle.Dashed,
      color: $r('app.color.divider_color')
    })
    .backgroundColor($r('app.color.card_color'))
    .width('100%')
    .margin({ top: $$.target === 0 ? 0 : 12 })
    .allowDrop([utd.UniformDataType.FILE, utd.UniformDataType.FILE_URI])
    .onDrop((event: DragEvent) => {
      this.onDropSlot(event, $$.target);
    }, { disableDataPrefetch: true })
  }

  @Builder
  algoGroup() {
    // 算法
    TabSegmentButtonV2({
      items: this.algoItems,
      selectedIndex: this.algoIndex,
      $selectedIndex: (index: number) => {
        this.algoIndex = index;
        this.compareVisible = false;
      },
      enableStateAnimation: true
    })
      .width('100%')
      .margin({ top: 12 })

    Button(this.busy ? this.str($r('app.string.computing')) : this.str($r('app.string.compute')))
      .enabled(!this.busy)
      .width('100%')
      .height(44)
      .margin({ top: 16 })
      .backgroundColor(this.busy ? $r('app.color.disabled_bg') : $r('app.color.primary_color'))
      .fontColor(this.busy ? $r('app.color.text_tertiary') : $r('app.color.card_color'))
      .onClick(() => {
        this.computeAndCompare();
      })
  }

  @Builder
  resultGroup() {
    // 粘贴哈希值
    Column() {
      Row() {
        // 默认两行高的文本框，方便核对长哈希
        TextArea({ placeholder: this.str($r('app.string.paste_hash_hint')), text: this.pastedHash })
          .fontSize(14)
          .fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_tertiary'))
          .backgroundColor($r('app.color.chip_bg'))
          .borderRadius(8)
          .layoutWeight(1)
          .height(72)
          .onChange((value: string) => {
            this.pastedHash = value;
          })

        // 右侧一列：安全粘贴按钮 + 扫码按钮上下排列
        Column({ space: 8 }) {
          // 剪贴板读取走 PasteButton 安全控件：点击即临时授权，无需权限申请
          PasteButton()
            .height(32)
            .fontSize(12)
            .onClick(this.handlePasteButtonClick)

          Button(this.str($r('app.string.scan_qr')))
            .height(32)
            .fontSize(12)
            .padding({ left: 12, right: 12 })
            .backgroundColor($r('app.color.chip_bg'))
            .fontColor($r('app.color.primary_color'))
            .onClick(() => {
              this.scanExpected();
            })
        }
        .margin({ left: 8 })
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
    }
    .padding(16)
    .borderRadius(16)
    .backgroundColor($r('app.color.card_color'))
    .width('100%')
    .margin({ top: this.isWide ? 0 : 12 })

    if (this.compareVisible) {
      Row({ space: 8 }) {
        SymbolGlyph(this.compareSame ? $r('sys.symbol.checkmark') : $r('sys.symbol.xmark'))
          .fontSize(24)
          .fontColor([this.compareSame ? $r('app.color.success_color') : $r('app.color.danger_color')])
        Text(this.compareText)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.compareSame ? $r('app.color.success_color') : $r('app.color.danger_color'))
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 20, bottom: 20 })
      .borderRadius(16)
      .backgroundColor($r('app.color.card_color'))
      .border({ width: 2, color: this.compareSame ?
        $r('app.color.success_color') :
        $r('app.color.danger_color') })
      .justifyContent(FlexAlign.Center)
      .margin({ top: 16 })
    } else if (this.isWide) {
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
              this.slotCard({ slot: this.slotA, target: 0 })
              this.slotCard({ slot: this.slotB, target: 1 })
              this.algoGroup()
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
            this.slotCard({ slot: this.slotA, target: 0 })
            this.slotCard({ slot: this.slotB, target: 1 })
            this.algoGroup()
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
