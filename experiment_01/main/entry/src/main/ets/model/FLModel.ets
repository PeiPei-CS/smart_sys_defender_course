export const INPUT_SIZE: number = 784;
export const CLASS_COUNT: number = 10;
export const PARAMETER_COUNT: number = INPUT_SIZE * CLASS_COUNT + CLASS_COUNT;

export class EvaluationResult {
  accuracy: number;
  loss: number;
  constructor(accuracy: number, loss: number) { this.accuracy = accuracy; this.loss = loss; }
}

export class FLModel {
  weights: number[];
  constructor(weights: number[]) { this.weights = weights; }
  static zeros(): FLModel { return new FLModel(new Array<number>(PARAMETER_COUNT).fill(0)); }

  predict(x: number[]): number[] {
    const probs = new Array<number>(CLASS_COUNT).fill(0);
    for (let c = 0; c < CLASS_COUNT; c++) {
      let z = this.weights[INPUT_SIZE * CLASS_COUNT + c];
      for (let f = 0; f < INPUT_SIZE; f++) z += x[f] * this.weights[f * CLASS_COUNT + c];
      probs[c] = z;
    }
    const maxZ = Math.max(...probs);
    let total = 0;
    for (let c = 0; c < CLASS_COUNT; c++) { probs[c] = Math.exp(Math.max(-40, probs[c] - maxZ)); total += probs[c]; }
    for (let c = 0; c < CLASS_COUNT; c++) probs[c] /= total;
    return probs;
  }

  train(xs: number[][], ys: number[], lr: number): void {
    const gradient = new Array<number>(PARAMETER_COUNT).fill(0);
    const n = xs.length;
    for (let i = 0; i < n; i++) {
      const p = this.predict(xs[i]);
      for (let c = 0; c < CLASS_COUNT; c++) {
        const e = p[c] - (ys[i] === c ? 1 : 0);
        for (let f = 0; f < INPUT_SIZE; f++) gradient[f * CLASS_COUNT + c] += e * xs[i][f] / n;
        gradient[INPUT_SIZE * CLASS_COUNT + c] += e / n;
      }
    }
    for (let i = 0; i < PARAMETER_COUNT; i++) this.weights[i] -= lr * gradient[i];
  }

  evaluate(xs: number[][], ys: number[]): EvaluationResult {
    let correct = 0; let totalLoss = 0;
    for (let i = 0; i < xs.length; i++) {
      const p = this.predict(xs[i]); let best = 0;
      for (let c = 1; c < CLASS_COUNT; c++) if (p[c] > p[best]) best = c;
      if (best === ys[i]) correct++;
      totalLoss -= Math.log(Math.max(p[ys[i]], 1e-12));
    }
    return new EvaluationResult(correct / xs.length, totalLoss / xs.length);
  }
}
