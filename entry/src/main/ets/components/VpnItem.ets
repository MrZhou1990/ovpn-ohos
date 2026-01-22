import hilog from '@ohos.hilog';
import { BUNDLE_NAME } from 'BuildProfile';
import { vpnExtension as vpnExt } from '@kit.NetworkKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { showToast } from '../components/Common';

const TAG: string = '[ItemVpn]'
const bundleName = BUNDLE_NAME
const abilityName = 'OvpnExtAbility'

@Component
export struct VpnItem {
  @Prop name: string = ''
  @Prop cfg: string = ''
  @Prop fullPath: string = ''
  @Prop remote: string = ''
  @State display: boolean = false
  @State isOn: boolean = false

  build() {
    Row() {
      Column() {
        Text(this.name)
        Text(this.remote).margin({ top: 10 })
      }
      .width('85%')
      .alignItems(HorizontalAlign.Start)

      Toggle({ type: ToggleType.Switch, isOn: this.isOn })
        .onChange(async (isOn) => {
          this.isOn = isOn
          if (isOn) {
            await this.startVpn()
          } else {
            await this.stopVpn()
          }
        })
    }
    .width('calc(100% - 30vp)')
    .borderRadius('15px')
    .borderWidth('1px')
    .borderColor(Color.Gray)
    .padding(15)
    .backgroundColor('#F9FAFB')
    .margin({
      top: 15
    })
  }

  async startVpn() {
    try {
      await vpnExt.startVpnExtensionAbility({ bundleName, abilityName, parameters: { cfg: this.cfg } })
      showToast(this.getUIContext(), 'start vpnExt Success', 2000);
      hilog.info(0x0000, TAG, '%{public}s', 'start vpnExt Success');
    } catch (err) {
      showToast(this.getUIContext(), 'start vpnExt Fail: ' + JSON.stringify(err), 2000);
      hilog.error(0x0000, TAG, 'start vpnExt Fail %{public}s', JSON.stringify(err) ?? '');
    }
  }

  async stopVpn() {
    try {
      await vpnExt.stopVpnExtensionAbility({ bundleName, abilityName })
      showToast(this.getUIContext(), 'stop vpnExt Success', 2000);
      hilog.info(0x0000, TAG, '%{public}s', 'stop vpnExt Success');
    } catch (err) {
      showToast(this.getUIContext(), 'stop vpnExt Fail: ' + JSON.stringify(err), 2000);
      hilog.error(0x0000, TAG, 'stop vpnExt Fail %{public}s', JSON.stringify(err) ?? '');
    }
  }
}
