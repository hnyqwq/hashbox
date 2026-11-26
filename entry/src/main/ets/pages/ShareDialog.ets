import { common, UIExtensionContentSession, Want } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { systemShare } from '@kit.ShareKit';

const BUNDLE_NAME: string = 'yylx.hnyqwq.hashbox';
const ENTRY_ABILITY_NAME: string = 'EntryAbility';

/**
 * 分享扩展的转发对话框：
 * 分享的文件数据存于 UDMF，须经 systemShare.getSharedData 解析出文件 URI，
 * 再经 parameters 交接给主 Ability 后自动关闭。
 */
@Entry
@Component
struct ShareDialog {
  localStorage = this.getUIContext().getSharedLocalStorage();
  private want: Want | undefined = this.localStorage?.get<Want>('ShareExtAbilityWant');
  private session: UIExtensionContentSession | undefined =
    this.localStorage?.get<UIExtensionContentSession>('ShareExtAbilitySession');
  private forwarded: boolean = false;

  aboutToAppear(): void {
    this.forwardToMain();
  }

  private closeDialog(resultCode: systemShare.ShareAbilityResultCode): void {
    this.session?.terminateSelfWithResult({ resultCode: resultCode }).catch((error: BusinessError) => {
      console.error(`terminateSelfWithResult error. Code: ${error?.code}, message: ${error?.message}`);
    });
  }

  /** 分享扩展内禁止直接拉起三方应用(16000069)，统一交接给本应用 UIAbility */
  private async forwardToMain(): Promise<void> {
    if (this.forwarded) {
      return;
    }
    this.forwarded = true;
    let fileUri = '';
    if (this.want !== undefined && this.want.uri !== undefined && this.want.uri.length > 0) {
      fileUri = this.want.uri;
    }
    if (fileUri === '' && this.want !== undefined) {
      try {
        const sharedData = await systemShare.getSharedData(this.want);
        const records = sharedData.getRecords();
        for (const rec of records) {
          if (rec.uri !== undefined && rec.uri.length > 0) {
            fileUri = rec.uri;
            break;
          }
        }
      } catch (e) {
        console.error(`getSharedData error. Code: ${(e as BusinessError)?.code}`);
      }
    }
    console.error('ShareDialog', 'forward uri=' + (fileUri === '' ? 'none' : fileUri));
    if (fileUri === '') {
      this.closeDialog(systemShare.ShareAbilityResultCode.CLOSE);
      return;
    }
    const context = this.getUIContext().getHostContext() as common.UIExtensionContext;
    const params: Record<string, Object> = { 'hashbox_forward_uri': fileUri };
    const want: Want = {
      bundleName: BUNDLE_NAME,
      abilityName: ENTRY_ABILITY_NAME,
      parameters: params
    };
    context.startAbility(want).then(() => {
      this.closeDialog(systemShare.ShareAbilityResultCode.CLOSE);
    }).catch((error: BusinessError) => {
      console.error(`forward error. Code: ${error?.code}, message: ${error?.message}`);
      this.closeDialog(systemShare.ShareAbilityResultCode.CLOSE);
    });
  }

  build() {
    Column({ space: 12 }) {
      LoadingProgress()
        .width(32)
        .height(32)
        .color($r('app.color.primary_color'))
      Text($r('app.string.share_forwarding'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
    }
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_color'))
  }
}
