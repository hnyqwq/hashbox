import { AbilityConstant, common, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { display, window } from '@kit.ArkUI';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppStorage.setOrCreate<common.UIAbilityContext>('context', this.context);
    // 设置项默认值（Prefs.init 会覆盖）
    AppStorage.setOrCreate<string>('defaultAlgo', 'sha256');
    AppStorage.setOrCreate<string>('sizeUnit', 'auto');
    AppStorage.setOrCreate<string>('historyVersion', '0');
    AppStorage.setOrCreate<number>('topRectHeight', 0);
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
    this.handleWant(want);
  }

  /** 文件关联打开：外部"打开方式"传入的文件 URI 写入 AppStorage，供文件信息页消费 */
  private handleWant(want: Want): void {
    let uri = want.uri;
    if (uri === undefined || uri.length === 0) {
      const forwarded = want.parameters?.['hashbox_forward_uri'];
      if (typeof forwarded === 'string' && forwarded.length > 0) {
        uri = forwarded;
      }
    }
    console.error('EntryAbility', 'handleWant uri=' + (uri !== undefined ? uri : 'none'));
    if (uri !== undefined && uri.length > 0) {
      AppStorage.setOrCreate<string>('openedFileUri', uri);
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    // 记录状态栏+挖孔高度（px），供右上角设置按钮避让
    try {
      const mainWindow = windowStage.getMainWindowSync();
      const updateTopAvoid = (): void => {
        const systemArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
        const cutoutArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_CUTOUT);
        const topPx = Math.max(systemArea.topRect.height, cutoutArea.topRect.height);
        AppStorage.setOrCreate<number>('topRectHeight', topPx);
      };
      updateTopAvoid();
      mainWindow.on('avoidAreaChange', () => {
        updateTopAvoid();
      });
      // 一多断点：窗口宽度 >= 600vp 视为宽屏（平板/折叠屏展开/横屏）
      const updateIsWide = (): void => {
        try {
          const rect = mainWindow.getWindowProperties().windowRect;
          const density = display.getDefaultDisplaySync().densityPixels;
          AppStorage.setOrCreate<boolean>('isWide', density > 0 && rect.width / density >= 600);
        } catch (err) {
          AppStorage.setOrCreate<boolean>('isWide', false);
        }
      };
      updateIsWide();
      mainWindow.on('windowSizeChange', () => {
        updateIsWide();
      });
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to get avoid area. Cause: %{public}s', JSON.stringify(err));
    }

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.handleWant(want);
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
