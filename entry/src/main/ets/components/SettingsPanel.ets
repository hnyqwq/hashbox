import { common } from '@kit.AbilityKit';
import { SegmentButtonV2Items, TabSegmentButtonV2 } from '@kit.ArkUI';
import { Prefs, ALGO_CODES } from '../common/Prefs';

/**
 * 右上角设置面板（bindSheet 弹出，高度自适应内容）：
 * 仅默认算法、文件大小单位；历史记录移至独立面板。
 */
/** 文件大小单位编码（与 sizeUnit 存储值一致） */
const UNIT_CODES: string[] = ['auto', 'b', 'kb', 'mb'];

@Component
export struct SettingsPanel {
  @Link showPanel: boolean;
  @StorageLink('defaultAlgo') defaultAlgo: string = 'sha256';
  @StorageLink('sizeUnit') sizeUnit: string = 'auto';

  private resManager: common.Context | undefined = undefined;

  private algoItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: 'MD5' },
    { text: 'SHA1' },
    { text: 'SHA256' }
  ]);

  private unitItems: SegmentButtonV2Items = new SegmentButtonV2Items([
    { text: 'AUTO' },
    { text: 'B' },
    { text: 'KB' },
    { text: 'MB' }
  ]);

  aboutToAppear(): void {
    this.resManager = getContext(this) as common.Context;
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

  @Builder
  sectionTitle(res: Resource) {
    Text(this.str(res))
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor($r('app.color.text_secondary'))
      .width('100%')
      .margin({ top: 20, bottom: 8 })
  }

  build() {
    Column() {
      Text(this.str($r('app.string.title_settings')))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .margin({ bottom: 4 })

      Column() {
          // 默认算法
          this.sectionTitle($r('app.string.settings_default_algo'))
          TabSegmentButtonV2({
            items: this.algoItems,
            selectedIndex: ALGO_CODES.indexOf(this.defaultAlgo),
            $selectedIndex: (index: number) => {
              Prefs.setDefaultAlgo(ALGO_CODES[index]);
            },
            enableStateAnimation: true
          })
            .width('100%')

          // 大小单位
          this.sectionTitle($r('app.string.settings_size_unit'))
          TabSegmentButtonV2({
            items: this.unitItems,
            selectedIndex: UNIT_CODES.indexOf(this.sizeUnit),
            $selectedIndex: (index: number) => {
              Prefs.setSizeUnit(UNIT_CODES[index]);
            },
            enableStateAnimation: true
          })
            .width('100%')

          Text('').height(20)
        }
        .width('100%')
    }
    .padding({ left: 20, right: 20, top: 20, bottom: 20 })
    .width('100%')
  }
}
