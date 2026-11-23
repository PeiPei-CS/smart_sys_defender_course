import { pasteboard } from '@kit.BasicServicesKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { ExperimentConfig, FederatedExperiment, RoundRecord } from '../model/FederatedExperiment';
import { ExperimentReport } from '../model/ExperimentReport';

@Entry
@Component
struct Index {
  @State running: boolean = false;
  @State status: string = '准备就绪：20 客户端 / 4 恶意端 / 10 轮';
  @State rows: RoundRecord[] = [];
  @State csvText: string = '';
  @State selected: string = 'clean';
  @State cleanAccuracy: number = 0;
  @State attackAccuracy: number = 0;
  @State defendedAccuracy: number = 0;
  @State roundText: string = '尚未运行';
  private config: ExperimentConfig = new ExperimentConfig();

  private async runExperiments(): Promise<void> {
    if (this.running) return;
    this.running = true; this.rows = []; this.cleanAccuracy = 0; this.attackAccuracy = 0; this.defendedAccuracy = 0;
    const experiment = new FederatedExperiment(this.config);
    const groups: string[] = ['clean', 'fedavg', 'trimmed'];
    const labels: string[] = ['干净基准', '投毒 + FedAvg', '投毒 + Trimmed Mean'];
    const finalAcc: number[] = [0, 0, 0];
    try {
      for (let g = 0; g < groups.length; g++) {
        let weights = experiment.initialModel();
        for (let r = 1; r <= this.config.rounds; r++) {
          this.status = labels[g] + ' · 第 ' + r + '/' + this.config.rounds + ' 轮';
          await new Promise<void>((resolve: () => void) => setTimeout(() => resolve(), 10));
          const record = experiment.runRound(groups[g], r, weights);
          this.rows = this.rows.concat([record]);
          finalAcc[g] = record.accuracy;
          this.roundText = labels[g] + ' / 第 ' + r + ' 轮';
        }
        if (g === 0) this.cleanAccuracy = finalAcc[g];
        if (g === 1) this.attackAccuracy = finalAcc[g];
        if (g === 2) this.defendedAccuracy = finalAcc[g];
      }
      const fedRows = this.rows.filter((row: RoundRecord) => row.group === 'fedavg');
      for (let i = 0; i < this.rows.length; i++) {
        const row = this.rows[i];
        const matching = fedRows.find((fed: RoundRecord) => fed.round === row.round);
        row.defenseGainPP = row.group === 'trimmed' && matching ? (row.accuracy - matching.accuracy) * 100 : 0;
      }
      this.rows = this.rows.slice();
      this.csvText = ExperimentReport.toCsv(this.rows, this.config);
      this.status = '三组对照完成：共 ' + this.rows.length + ' 条逐轮记录';
    } catch (error) {
      this.status = '实验异常：' + JSON.stringify(error);
    }
    this.running = false;
  }

  private async saveCsv(): Promise<void> {
    if (this.rows.length === 0) { this.status = '请先完成实验，再导出 CSV'; return; }
    try {
      const path = this.getUIContext().getHostContext()!.filesDir + '/fl_comparison_seed20260909.csv';
      const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      fs.writeSync(file.fd, this.csvText);
      fs.closeSync(file);
      this.status = 'CSV 已保存到应用沙箱：' + path;
    } catch (error) { this.status = '保存失败：' + JSON.stringify(error); }
  }

  private async copyCsv(): Promise<void> {
    if (this.rows.length === 0) { this.status = '请先完成实验，再复制 CSV'; return; }
    try {
      const data = pasteboard.createData("text/plain", this.csvText);
      await pasteboard.getSystemPasteboard().setData(data);
      this.status = 'CSV 已复制，可粘贴到报告或 UTF-8 .csv 文件';
    } catch (error) { this.status = '复制失败：' + JSON.stringify(error); }
  }

  private percent(value: number): string { return (value * 100).toFixed(1) + '%'; }

  private finalAccuracy(group: string): number {
    let value = 0;
    for (let i = 0; i < this.rows.length; i++) if (this.rows[i].group === group) value = this.rows[i].accuracy;
    return value;
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Column({ space: 6 }) {
          Text('联邦学习投毒与防护').fontSize(25).fontWeight(FontWeight.Bold).fontColor('#F4F7FF');
          Text('HarmonyOS 端侧协同攻防实验').fontSize(14).fontColor('#A9B8D0');
        }.alignItems(HorizontalAlign.Start).width('100%');

        Column({ space: 8 }) {
          Text('实验配置').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#F4F7FF');
          Text(this.config.clients + ' 客户端 · ' + this.config.maliciousClients + ' 恶意端 · 每端 40 条 · 测试集 200 条').fontSize(13).fontColor('#C6D2E4');
          Text('10 轮 · 本地训练 1 轮 · 学习率 0.01 · 种子 20260909').fontSize(13).fontColor('#C6D2E4');
          Text('攻击：' + (this.config.attackType === 'scale' ? '恶意更新反向放大 −' + this.config.attackScale + '×' : '标签翻转') + '   |   防御：坐标截断均值，双侧各裁剪 ' + this.config.maliciousClients + ' 个更新').fontSize(13).fontColor('#C6D2E4');
          Text('模型：784 → 10，7,850 参数   |   三组共享数据、测试集和初始权重').fontSize(12).fontColor('#8FA2BD');
        }.padding(14).width('100%').backgroundColor('#17243A').borderRadius(14).alignItems(HorizontalAlign.Start);

        Column({ space: 8 }) {
          Text('可调参数').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#F4F7FF');
          Row({ space: 6 }) { Text('客户端').fontSize(12).fontColor('#C6D2E4'); Button('−').onClick(() => { this.config.clients = Math.max(4, this.config.clients - 1); this.config.maliciousClients = Math.min(this.config.maliciousClients, this.config.clients - 1); this.status = '参数已更新'; }); Text(this.config.clients.toString()).fontColor('#FFFFFF'); Button('+').onClick(() => { this.config.clients = Math.min(40, this.config.clients + 1); this.status = '参数已更新'; }); Text('恶意端').fontSize(12).fontColor('#C6D2E4'); Button('−').onClick(() => { this.config.maliciousClients = Math.max(0, this.config.maliciousClients - 1); this.status = '参数已更新'; }); Text(this.config.maliciousClients.toString()).fontColor('#FFFFFF'); Button('+').onClick(() => { this.config.maliciousClients = Math.min(this.config.clients - 1, this.config.maliciousClients + 1); this.status = '参数已更新'; });
          }.width('100%');
          Row({ space: 6 }) { Text('轮数').fontSize(12).fontColor('#C6D2E4'); Button('−').onClick(() => { this.config.rounds = Math.max(1, this.config.rounds - 1); this.status = '参数已更新'; }); Text(this.config.rounds.toString()).fontColor('#FFFFFF'); Button('+').onClick(() => { this.config.rounds = Math.min(30, this.config.rounds + 1); this.status = '参数已更新'; }); Button(this.config.attackType === 'scale' ? '攻击：更新放大' : '攻击：标签翻转').onClick(() => { this.config.attackType = this.config.attackType === 'scale' ? 'label' : 'scale'; this.status = '参数已更新'; }); Button('倍率 ' + this.config.attackScale + '×').onClick(() => { this.config.attackScale = this.config.attackScale >= 10 ? 2 : this.config.attackScale + 1; this.status = '参数已更新'; });
          }.width('100%');
        }.padding(12).backgroundColor('#17243A').borderRadius(12).width('100%');

        Row({ space: 8 }) {
          this.groupChip('clean', '干净基准');
          this.groupChip('fedavg', '投毒/FedAvg');
          this.groupChip('trimmed', '投毒/防御');
        }.width('100%');

        Button(this.running ? '实验运行中…' : '开始三组对照实验')
          .width('100%').height(50).fontSize(17).fontWeight(FontWeight.Bold)
          .backgroundColor('#4C83F5').enabled(!this.running).onClick(() => { this.runExperiments(); });
        Text(this.status).fontSize(13).fontColor('#AFC1D9').width('100%');

        Row({ space: 8 }) {
          this.metricCard('干净·第10轮', 'clean', '#4CD3A4');
          this.metricCard('FedAvg·第10轮', 'fedavg', '#FF7C86');
          this.metricCard('防御·第10轮', 'trimmed', '#7FA8FF');
        }.width('100%');

        Column({ space: 8 }) {
          Text('逐轮结果 · ' + (this.selected === 'clean' ? '干净基准' : this.selected === 'fedavg' ? '投毒 / FedAvg' : '投毒 / Trimmed Mean')).fontSize(18).fontWeight(FontWeight.Bold).fontColor('#F4F7FF');
          Row() {
            Text('组别 / 轮次').width('42%').fontSize(11).fontColor('#91A4BF'); Text('Accuracy').width('22%').fontSize(11).fontColor('#91A4BF'); Text('Loss').width('18%').fontSize(11).fontColor('#91A4BF'); Text('收益(pp)').width('18%').fontSize(11).fontColor('#91A4BF');
          }.width('100%');
          ForEach(this.rows.filter((row: RoundRecord) => this.selected === 'all' || row.group === this.selected), (row: RoundRecord) => {
            Row() {
              Text((row.group === 'clean' ? '干净' : row.group === 'fedavg' ? 'FedAvg' : 'Trimmed') + ' / ' + row.round).width('42%').fontSize(12).fontColor('#D8E1EE');
              Text(this.percent(row.accuracy)).width('22%').fontSize(12).fontColor(row.group === 'fedavg' ? '#FF9098' : '#6DE0B5');
              Text(row.loss.toFixed(3)).width('18%').fontSize(12).fontColor('#D8E1EE');
              Text(row.defenseGainPP.toFixed(1)).width('18%').fontSize(12).fontColor('#D8E1EE');
            }.padding({ top: 7, bottom: 7 }).width('100%').border({ width: { bottom: 0.5 }, color: '#293852' });
          }, (row: RoundRecord) => row.group + '-' + row.round);
        }.padding(14).width('100%').backgroundColor('#17243A').borderRadius(14).alignItems(HorizontalAlign.Start);

        Row({ space: 10 }) {
          Button('保存 CSV').layoutWeight(1).backgroundColor('#263956').onClick(() => { this.saveCsv(); });
          Button('复制 CSV').layoutWeight(1).backgroundColor('#263956').onClick(() => { this.copyCsv(); });
        }.width('100%');
        Text('报告提醒：保存参数、运行结果和 CSV 导出截图。课堂参考精度仅供比较，报告填写本机实测值。').fontSize(12).fontColor('#9FB0C8').width('100%');
      }.padding(18).width('100%').alignItems(HorizontalAlign.Start);
    }.width('100%').height('100%').backgroundColor('#0D1728').scrollBar(BarState.Auto);
  }

  @Builder
  private groupChip(key: string, title: string) {
    Button(title).layoutWeight(1).fontSize(11).backgroundColor(this.selected === key ? '#35598C' : '#1B2A40')
      .onClick(() => { this.selected = key; });
  }

  @Builder
  private metricCard(title: string, group: string, color: string) {
    Column({ space: 5 }) {
      Text(title).fontSize(10).fontColor('#A9B8D0');
      Text(this.percent(this.finalAccuracy(group))).fontSize(17).fontWeight(FontWeight.Bold).fontColor(color);
    }.layoutWeight(1).padding(10).backgroundColor('#17243A').borderRadius(12).alignItems(HorizontalAlign.Start);
  }
}







