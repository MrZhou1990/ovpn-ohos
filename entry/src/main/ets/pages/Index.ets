import hilog from '@ohos.hilog';
import { BUNDLE_NAME } from 'BuildProfile';
import { connection } from '@kit.NetworkKit';
import { picker, fileIo as fs, fileUri } from '@kit.CoreFileKit';
import { BasicDataSource, showToast } from '../components/Common';
import { BusinessError, commonEventManager } from '@kit.BasicServicesKit';
import { VpnItem } from '../components/VpnItem';
import VPNTools from '../tools/VPNTools'

const TAG: string = '[PageIndex]'

interface connectData {
  info: string
  proxy: connection.HttpProxy
}

let ctx: UIContext
try {
  commonEventManager.createSubscriber({
    events: ['ovpn.READ_CONFIG_ERR', 'ovpn.CONNECTED', 'ovpn.DESTROY'],
    publisherBundleName: BUNDLE_NAME
  },
    (err: BusinessError, subscriber: commonEventManager.CommonEventSubscriber) => {
      if (err) {
        hilog.error(0x0000, TAG, `createSubscriberErr: ${err.code}, name: ${err.name}, msg: ${err.message}`);
        return
      }
      commonEventManager.subscribe(subscriber, (err: BusinessError, data: commonEventManager.CommonEventData) => {
        if (err) {
          hilog.error(0x0000, TAG, `subscribe event err: ${err.code}, name: ${err.name}, msg: ${err.message}`);
          return
        }
        if (data.event === 'ovpn.CONNECTED' && data.data) {
          const s = data.data as string
          const d = JSON.parse(s) as connectData;
          hilog.info(0x0000, TAG, `Connected: ${d.info}`);
          showToast(ctx, `Connected: ${d.info}`, 3000);
          if (d.proxy?.host) {
            setVpnNet(d.proxy)
          }
          return;
        }
        hilog.info(0x0000, TAG, `subscribe event: ${data.event}, data: ${data.data}`);
      })
    });
} catch (e) {
  hilog.error(0x0000, TAG, `createSubscriber failed, code is ${JSON.stringify(e)}`);
}

interface ItemData {
  name: string
  cfg: string
  fullPath: string
  remote?: string
}

@Entry
@Component
struct Index {
  private data: BasicDataSource<ItemData> = new BasicDataSource<ItemData>();
  @State vpnConfig: string = '';
  @Provide('navPathStack') navPathStack: NavPathStack = new NavPathStack();

  getDir(): string {
    return this.getUIContext().getHostContext()?.filesDir + '/ovpn'
  }

  async aboutToAppear() {
    ctx = this.getUIContext()
    const dir = this.getDir()
    try {
      await fs.mkdir(dir)
    } catch (e) {
    }
    try {
      const files = await fs.listFile(dir)
      for (let name of files) {
        const fullPath = dir + '/' + name
        const cfg = await fs.readText(fullPath)
        const remote = VPNTools.clientRemoteIP(cfg)
        this.data.push({
          name,
          cfg,
          fullPath,
          remote
        })
      }
    } catch (e) {
      console.error(e)
    }
  }

  build() {
    Navigation(this.navPathStack) {
      RelativeContainer() {
        Column() {
          Text('Have a configuration file instead (.ovpn)?')
          Button({ type: ButtonType.Normal }) {
            Row() {
              Image($r('app.media.uploadfile'))
                .width(25)
                .height(25)
              Text('Upload File')
                .margin({
                  left: 10
                })
            }
          }
          .backgroundColor('#F9FAFB')
          .borderRadius('15px')
          .borderWidth('1px')
          .borderColor(Color.Gray)
          .padding({
            top: 5,
            bottom: 5,
            left: 20,
            right: 20
          })
          .margin({
            top: 15
          })
          .onClick(async () => {
            try {
              const dp = new picker.DocumentViewPicker();
              const uris = await dp.select({ fileSuffixFilters: ['.ovpn'] })
              if (!uris || !uris.length) {
                return
              }
              const dir = this.getDir()
              for (let uri of uris) {
                const fUri = new fileUri.FileUri(uri)
                const cfg = await fs.readText(fUri.path)
                const fullPath = `${dir}/${fUri.name}`
                const fd = await fs.open(fullPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE)
                await fs.write(fd.fd, cfg)
                await fs.close(fd)
                const remote = VPNTools.clientRemoteIP(cfg)
                this.data.push({
                  name: fUri.name,
                  cfg,
                  fullPath,
                  remote
                })
              }
            } catch (e) {
              showToast(this.getUIContext(), `fileErr: ${JSON.stringify(e)}`, 4000);
            }
          })
        }
        .alignRules({
          left: { anchor: "__container__", align: HorizontalAlign.Start },
          right: { anchor: "__container__", align: HorizontalAlign.End },
          top: { anchor: "__container__", align: VerticalAlign.Top },
        })
        .backgroundColor('#F9FAFB')
        .padding({
          top: 20,
          bottom: 20
        })
        .margin(15)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .borderRadius('15px')
        .borderWidth('1px')
        .borderColor(Color.Gray)
        .id('column1')

        List() {
          LazyForEach(this.data, (item: ItemData) => {
            ListItem() {
              VpnItem(item)
            }
            .width('100%')
            .gesture(
              LongPressGesture()
                .onAction((event: GestureEvent) => {
                  this.getUIContext().showAlertDialog({
                    title: '温馨提示',
                    message: '您确定删除当前配置文件吗？',
                    primaryButton: {
                      value: '确定',
                      action: () => {

                      }
                    },
                    secondaryButton: {
                      value: '取消',
                      defaultFocus: true,
                      action: () => {

                      }
                    },
                    cancel: () => {

                    }
                  })
                })
            )
          })
        }
        .alignRules({
          left: { anchor: "__container__", align: HorizontalAlign.Start },
          right: { anchor: "__container__", align: HorizontalAlign.End },
          top: { anchor: "column1", align: VerticalAlign.Bottom },
          bottom: { anchor: "__container__", align: VerticalAlign.Bottom }
        })
      }
      .width('100%')
      .height('100%')
    }
    .title('OpenVPN Connect')
    .backgroundColor(Color.White)
    .menus([
      {
        value: '日志',
        icon: $r('app.media.history_log'),
        action: async () => {
          this.navPathStack.pushPathByName('Log', '')
        }
      },
      {
        value: '清理',
        icon: $r('app.media.log_clear'),
        action: async () => {
          try {
            await fs.truncate(this.getUIContext().getHostContext()?.filesDir + '/ovpn.log')
            showToast(this.getUIContext(), `clear log success`, 1000);
          } catch (e) {
            showToast(this.getUIContext(), `clearLogErr: ${JSON.stringify(e)}`, 4000);
          }
        }
      }
    ])
  }
}

async function setVpnNet(proxy: connection.HttpProxy) {
  try {
    proxy.exclusionList = ['10.', '192.168', '172.16']
    connection.setAppHttpProxy(proxy)
  } catch (e) {
    hilog.error(0x0000, TAG, 'SetAppHttpProxyErr: %{public}s', JSON.stringify(e));
  }
}
