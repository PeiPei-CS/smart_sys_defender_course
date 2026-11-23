import { RoundRecord, ExperimentConfig } from './FederatedExperiment';

export class ExperimentReport {
  static toCsv(rows: RoundRecord[], config: ExperimentConfig): string {
    const lines: string[] = [];
    lines.push('group,round,accuracy,loss,defense_gain_pp,clients,malicious_clients,samples_per_client,test_samples,local_epochs,learning_rate,seed,attack_type,attack_multiplier');
    for (let i = 0; i < rows.length; i++) {
      lines.push(rows[i].group + ',' + rows[i].round + ',' + rows[i].accuracy.toFixed(6) + ',' + rows[i].loss.toFixed(6) + ',' + rows[i].defenseGainPP.toFixed(2) + ',' + config.clients + ',' + config.maliciousClients + ',' + config.samplesPerClient + ',' + config.testSamples + ',' + config.localEpochs + ',' + config.learningRate + ',' + config.seed + ',' + config.attackType + ',' + (config.attackType === 'scale' ? -config.attackScale : 1));
    }
    return lines.join('\n');
  }
}

