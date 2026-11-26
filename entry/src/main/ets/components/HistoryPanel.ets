import { common } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { Prefs } from '../common/Prefs';
import { FormatUtil } from '../common/FormatUtil';
import { HistoryEntry } from '../model/HashModels';

/**
 * 历史记录面板（独立 bindSheet 弹出，不再藏在设置里）：
 * 查看/复制单条/清空。
 */
@Component
export struct HistoryPanel {
  @StorageLink('sizeUnit') sizeUnit: string = 'auto';
  @StorageProp('historyVersion') @Watch('onHistoryChanged') historyVersion: string = '0';
  @State history: HistoryEntry[] = [];

  private resManager: common.Context | undefined = undefined;

  aboutToAppear(): void {
    this.resManager = getContext(this) as common.Context;
    this.reloadHistory();
  }

  private onHistoryChanged(): void {
    this.reloadHistory();
  }

  private reloadHistory(): void {
    Prefs.getHistory().then((list: HistoryEntry[]) => {
      this.history = list;
    }).catch(() => {
      console.error('load history failed');
    });
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

  private copyHistory(entry: HistoryEntry): void {
    try {
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, entry.hashValue);
      pasteboard.getSystemPasteboard().setDataSync(data);
      this.toast(this.str($r('app.string.copied')));
    } catch (e) {
      console.error('copy failed');
    }
  }

  private clearHistory(): void {
    Prefs.clearHistory().then(() => {
      this.history = [];
    }).catch(() => {
      console.error('clear history failed');
    });
  }

  private removeHistory(index: number): void {
    Prefs.removeHistory(index).then(() => {
      this.reloadHistory();
    }).catch(() => {
      console.error('remove history failed');
    });
  }

  build() {
    Column() {
      Row() {
        Text(this.str($r('app.string.settings_history')))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text(`${this.history.length}`)
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
          .margin({ left: 8 })
        Blank()
        Button(this.str($r('app.string.settings_clear_history')))
          .height(32)
          .fontSize(13)
          .backgroundColor($r('app.color.chip_bg'))
          .fontColor($r('app.color.danger_color'))
          .onClick(() => {
            this.clearHistory();
          })
      }
      .width('100%')
      .margin({ bottom: 12 })

      if (this.history.length === 0) {
        Text(this.str($r('app.string.history_empty')))
          .fontSize(13)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
          .padding({ top: 16, bottom: 24 })
      } else {
        List() {
          ForEach(this.history, (entry: HistoryEntry, index: number) => {
            ListItem() {
              Row() {
                Column() {
                  Text(`${entry.fileName} · ${entry.algo.toUpperCase()}`)
                    .fontSize(13)
                    .fontColor($r('app.color.text_primary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.MARQUEE })
                    .width('100%')
                  Text(entry.hashValue)
                    .fontSize(11)
                    .fontFamily('monospace')
                    .fontColor($r('app.color.hash_text_color'))
                    .maxLines(2)
                    .textOverflow({ overflow: TextOverflow.MARQUEE })
                    .width('100%')
                  Text(FormatUtil.formatSize(entry.size, this.sizeUnit))
                    .fontSize(11)
                    .fontColor($r('app.color.text_tertiary'))
                    .width('100%')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                Column() {
                  Button(this.str($r('app.string.copy')))
                    .height(28)
                    .fontSize(12)
                    .padding({ left: 12, right: 12 })
                    .backgroundColor($r('app.color.chip_bg'))
                    .fontColor($r('app.color.primary_color'))
                    .onClick(() => {
                      this.copyHistory(entry);
                    })
                  Button(this.str($r('app.string.delete')))
                    .height(28)
                    .fontSize(12)
                    .padding({ left: 12, right: 12 })
                    .margin({ top: 4 })
                    .backgroundColor($r('app.color.chip_bg'))
                    .fontColor($r('app.color.danger_color'))
                    .onClick(() => {
                      this.removeHistory(index);
                    })
                }
              }
              .width('100%')
              .padding({ top: 8, bottom: 8 })
            }
          }, (entry: HistoryEntry, index: number) => `${index}_${entry.time}_${entry.hashValue}`)
        }
        .width('100%')
        .height(320)
        .scrollBar(BarState.Off)
        .divider({
          strokeWidth: 1,
          color: $r('app.color.divider_color'),
          startMargin: 0,
          endMargin: 0
        })
      }

      Text('').height(12)
    }
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .borderRadius(16)
    .backgroundColor($r('app.color.card_color'))
    .width('100%')
    .margin({ top: 16 })
  }
}
