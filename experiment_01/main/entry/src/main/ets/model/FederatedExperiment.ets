import { SeededRandom } from './SeededRandom';
import { FLModel, INPUT_SIZE, PARAMETER_COUNT, EvaluationResult } from './FLModel';
import { ClientUpdate, Defense } from '../defense/Defense';

export class ExperimentConfig {
  clients: number = 20;
  maliciousClients: number = 4;
  samplesPerClient: number = 40;
  testSamples: number = 200;
  rounds: number = 10;
  localEpochs: number = 1;
  learningRate: number = 0.01;
  seed: number = 20260909;
  attackScale: number = 5;
  attackType: string = 'scale';
}

export class RoundRecord {
  group: string;
  round: number;
  accuracy: number;
  loss: number;
  defenseGainPP: number;
  constructor(group: string, round: number, metric: EvaluationResult, gain: number) {
    this.group = group; this.round = round; this.accuracy = metric.accuracy;
    this.loss = metric.loss; this.defenseGainPP = gain;
  }
}

class SampleSet {
  xs: number[][] = [];
  ys: number[] = [];
}

export class FederatedExperiment {
  private config: ExperimentConfig;
  private clientSets: SampleSet[] = [];
  private testSet: SampleSet = new SampleSet();
  private initialWeights: number[] = [];
  private groupWeights: Map<string, number[]> = new Map<string, number[]>();

  constructor(config: ExperimentConfig) { this.config = config; this.prepare(); }

  private prepare(): void {
    const rng = new SeededRandom(this.config.seed);
    const all = new SampleSet();
    const total = this.config.clients * this.config.samplesPerClient;
    for (let i = 0; i < total + this.config.testSamples; i++) {
      const label = Math.floor(rng.next() * 10);
      const x = new Array<number>(INPUT_SIZE);
      for (let f = 0; f < INPUT_SIZE; f++) x[f] = rng.normal() * 0.12;
      // Synthetic, linearly separable class signal in a 784-dimensional feature vector.
      x[label] += 1.8;
      x[10 + label] += 0.8;
      if (i < total) { all.xs.push(x); all.ys.push(label); }
      else { this.testSet.xs.push(x); this.testSet.ys.push(label); }
    }
    for (let client = 0; client < this.config.clients; client++) {
      const set = new SampleSet();
      for (let j = 0; j < this.config.samplesPerClient; j++) {
        const index = client * this.config.samplesPerClient + j;
        set.xs.push(all.xs[index]); set.ys.push(all.ys[index]);
      }
      this.clientSets.push(set);
    }
    this.initialWeights = new Array<number>(PARAMETER_COUNT);
    for (let i = 0; i < PARAMETER_COUNT; i++) this.initialWeights[i] = rng.normal() * 0.001;
  }

  runRound(group: string, round: number, currentWeights: number[]): RoundRecord {
    const baseWeights = round === 1 ? currentWeights : (this.groupWeights.get(group) || currentWeights);
    const updates: ClientUpdate[] = [];
    for (let client = 0; client < this.config.clients; client++) {
      const local = new FLModel(baseWeights.slice());
      const set = this.clientSets[client];
      for (let epoch = 0; epoch < this.config.localEpochs; epoch++) {
        if (group !== 'clean' && client < this.config.maliciousClients && this.config.attackType === 'label') {
          const flipped: number[] = [];
          for (let j = 0; j < set.ys.length; j++) flipped.push((set.ys[j] + 1) % 10);
          local.train(set.xs, flipped, this.config.learningRate);
        } else {
          local.train(set.xs, set.ys, this.config.learningRate);
        }
      }
      const delta = new Array<number>(PARAMETER_COUNT);
      const malicious = group !== 'clean' && client < this.config.maliciousClients;
      for (let p = 0; p < PARAMETER_COUNT; p++) {
        const change = local.weights[p] - baseWeights[p];
        delta[p] = malicious ? change * (this.config.attackType === 'scale' ? -this.config.attackScale : 1) : change;
      }
      updates.push(new ClientUpdate(delta, set.xs.length));
    }
    const aggregate = group === 'trimmed'
      ? Defense.trimmedMean(updates, this.config.maliciousClients)
      : Defense.fedAvg(updates);
    const next = new Array<number>(PARAMETER_COUNT);
    for (let p = 0; p < PARAMETER_COUNT; p++) next[p] = baseWeights[p] + aggregate[p];
    this.groupWeights.set(group, next);
    const metric = new FLModel(next).evaluate(this.testSet.xs, this.testSet.ys);
    return new RoundRecord(group, round, metric, 0);
  }

  initialModel(): number[] { return this.initialWeights.slice(); }
}





