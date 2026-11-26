import { common } from '@kit.AbilityKit';
import { LengthMetrics, SymbolGlyphModifier } from '@kit.ArkUI';
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  HdsTabs,
  HdsTabsController,
  hdsMaterial,
  ScrollEffectType,
} from '@kit.UIDesignKit';
import { Prefs } from '../common/Prefs';
import { VerifyPage } from '../components/VerifyPage';
import { ComparePage } from '../components/ComparePage';
import { BatchPage } from '../components/BatchPage';
import { SettingsPanel } from '../components/SettingsPanel';
import { FileInfoPage } from '../components/FileInfoPage';

/**
 * 哈希盒主框架：沉浸光感 Tab（HdsNavigation + HdsTabs）。
 * 材质检测 + GRADIENT_BLUR 标题栏 + 滚动联动，右上角设置入口（不占底部 Tab）。
 */
@Entry
@Component
struct Index {
  @State currentTab: number = 0;
  @State tabMaterialType: number = hdsMaterial.MaterialType.ADAPTIVE;
  @State tabMaterialLevel: number = hdsMaterial.MaterialLevel.SMOOTH;
  @State showSettings: boolean = false;
  @StorageProp('openedFileUri') @Watch('onOpenedFile') openedFileUri: string = '';
  @StorageProp('topRectHeight') topRectPx: number = 0;
  private tabsController: HdsTabsController = new HdsTabsController();

  private scrollerVerify: Scroller = new Scroller();
  private scrollerCompare: Scroller = new Scroller();
  private scrollerBatch: Scroller = new Scroller();
  private scrollerInfo: Scroller = new Scroller();

  private symbolVerify: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.doc_text'));
  private symbolCompare: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.doc_text'));
  private symbolBatch: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.square_grid_2x2'));
  private symbolInfo: SymbolGlyphModifier = new SymbolGlyphModifier($r('sys.symbol.info_circle'));

  private getCurScroll(): Scroller {
    if (this.currentTab === 1) {
      return this.scrollerCompare;
    }
    if (this.currentTab === 2) {
      return this.scrollerBatch;
    }
    return this.scrollerVerify;
  }

  private getMainTitle(): string {
    if (this.currentTab === 1) {
      return this.getString($r('app.string.title_compare'));
    }
    if (this.currentTab === 2) {
      return this.getString($r('app.string.title_batch'));
    }
    if (this.currentTab === 3) {
      return this.getString($r('app.string.tab_info'));
    }
    return this.getString($r('app.string.title_verify'));
  }

  /** 外部"打开方式"传入文件时，自动切到文件信息 Tab */
  private onOpenedFile(): void {
    console.error('Index', 'onOpenedFile uri=' + this.openedFileUri);
    if (this.openedFileUri !== '') {
      this.currentTab = 3;
      this.tabsController.changeIndex(3);
    }
  }

  private getString(res: Resource): string {
    const ctx = AppStorage.get<common.UIAbilityContext>('context');
    if (ctx === undefined) {
      return '';
    }
    return ctx.resourceManager.getStringSync(res);
  }

  async aboutToAppear(): Promise<void> {
    const ctx = AppStorage.get<common.UIAbilityContext>('context');
    if (ctx !== undefined) {
      await Prefs.init(ctx);
    }
    // 材质检测：无 IMMERSIVE 降级 ADAPTIVE+GENTLE，异常兜底 SMOOTH+ADAPTIVE
    try {
      const materialTypes: Array<hdsMaterial.MaterialType> = hdsMaterial.getSystemMaterialTypes();
      const hasImmersive: boolean =
        materialTypes.some((t: hdsMaterial.MaterialType) => t === hdsMaterial.MaterialType.IMMERSIVE);
      if (materialTypes.length === 0) {
        this.tabMaterialLevel = hdsMaterial.MaterialLevel.SMOOTH;
        this.tabMaterialType = hdsMaterial.MaterialType.ADAPTIVE;
      } else if (!hasImmersive) {
        this.tabMaterialLevel = hdsMaterial.MaterialLevel.GENTLE;
        this.tabMaterialType = hdsMaterial.MaterialType.ADAPTIVE;
      } else {
        this.tabMaterialLevel = hdsMaterial.MaterialLevel.EXQUISITE;
        this.tabMaterialType = hdsMaterial.MaterialType.IMMERSIVE;
      }
    } catch (err) {
      this.tabMaterialLevel = hdsMaterial.MaterialLevel.SMOOTH;
      this.tabMaterialType = hdsMaterial.MaterialType.ADAPTIVE;
      console.error('getSystemMaterialTypes failed');
    }
  }

  build() {
    HdsNavigation() {
      HdsTabs({ controller: this.tabsController }) {
          TabContent() {
            VerifyPage({ scroller: this.scrollerVerify })
          }
          .tabBar(new BottomTabBarStyle({ normal: this.symbolVerify }, $r('app.string.tab_verify')))

          TabContent() {
            ComparePage({ scroller: this.scrollerCompare })
          }
          .tabBar(new BottomTabBarStyle({ normal: this.symbolCompare }, $r('app.string.tab_compare')))

          TabContent() {
            BatchPage({ scroller: this.scrollerBatch })
          }
          .tabBar(new BottomTabBarStyle({ normal: this.symbolBatch }, $r('app.string.tab_batch')))

          TabContent() {
            FileInfoPage({ scroller: this.scrollerInfo })
          }
          .tabBar(new BottomTabBarStyle({ normal: this.symbolInfo }, $r('app.string.tab_info')))
        }
        .barPosition(BarPosition.End)
        .vertical(false)
        .barOverlap(true)
        .scrollable(true)
        .barFloatingStyle({
          barBottomMargin: 28,
          systemMaterialEffect: {
            materialType: this.tabMaterialType,
            materialLevel: this.tabMaterialLevel,
          },
        })
        .onChange((index: number) => {
          this.currentTab = index;
        })
      }
      .titleBar({
        content: {
          title: {
            mainTitle: this.getMainTitle()
          },
          menu: {
            value: [{
              content: {
                icon: $r('sys.symbol.gearshape'),
                action: (): void => {
                  this.showSettings = true;
                }
              }
            }]
          }
        },
        style: {
          scrollEffectOpts: {
            enableScrollEffect: true,
            scrollEffectType: ScrollEffectType.GRADIENT_BLUR,
            blurEffectiveStartOffset: LengthMetrics.vp(0),
            blurEffectiveEndOffset: LengthMetrics.vp(56),
          },
          originalStyle: {
            backgroundStyle: {
              backgroundColor: '#00ffffff'
            },
            contentStyle: {
              titleStyle: { mainTitleColor: $r('app.color.text_primary') }
            }
          },
          scrollEffectStyle: {
            backgroundStyle: {
              backgroundColor: '#00ffffff'
            },
            contentStyle: {
              titleStyle: { mainTitleColor: $r('app.color.text_primary') }
            }
          }
        }
      })
      .bindToScrollable([this.getCurScroll()])
      .mode(NavigationMode.Stack)
      .titleMode(HdsNavigationTitleMode.MINI)
      .hideBackButton(true)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
      .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.bg_color'))
    .bindSheet(this.showSettings, this.settingsSheetBuilder(), {
      preferType: SheetType.BOTTOM,
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      showClose: true,
      backgroundColor: $r('app.color.bg_color'),
      onWillDisappear: () => {
        this.showSettings = false;
      }
    })
  }

  @Builder
  settingsSheetBuilder() {
    SettingsPanel({ showPanel: $showSettings })
  }
}
