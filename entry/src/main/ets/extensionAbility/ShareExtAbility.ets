import { AbilityConstant, ShareExtensionAbility, UIExtensionContentSession, Want } from '@kit.AbilityKit';

/**
 * 系统分享扩展：文件管理器长按文件 →「打开方式/分享」列出哈希盒的入口。
 * 收到分享的文件 URI 后转发给 EntryAbility，复用文件信息页的消费链路。
 */
export default class ShareExtAbility extends ShareExtensionAbility {
  onCreate(launchParam: AbilityConstant.LaunchParam): void {
    // 系统分享拉起（ReasonMessage_SystemShare），文件 URI 在 onSessionCreate 的 want 中
  }

  onSessionCreate(want: Want, session: UIExtensionContentSession): void {
    const para: Record<string, Object> = {
      'ShareExtAbilityWant': want,
      'ShareExtAbilitySession': session
    };
    const storage = new LocalStorage(para);
    try {
      session.loadContent('pages/ShareDialog', storage);
    } catch (e) {
      console.error(`loadContent error. Code: ${e?.code}, message: ${e?.message}`);
    }
  }
}
