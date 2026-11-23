export class ClientUpdate {
  delta: number[];
  sampleCount: number;
  constructor(delta: number[], sampleCount: number) { this.delta = delta; this.sampleCount = sampleCount; }
}

export class Defense {
  static fedAvg(updates: ClientUpdate[]): number[] {
    const result = new Array<number>(updates[0].delta.length).fill(0);
    let total = 0;
    for (let i = 0; i < updates.length; i++) total += updates[i].sampleCount;
    for (let i = 0; i < updates.length; i++) {
      const weight = updates[i].sampleCount / total;
      for (let p = 0; p < result.length; p++) result[p] += updates[i].delta[p] * weight;
    }
    return result;
  }

  // Coordinate-wise trimmed mean. The experiment trims f client values at both tails per parameter.
  static trimmedMean(updates: ClientUpdate[], f: number): number[] {
    const result = new Array<number>(updates[0].delta.length).fill(0);
    const trim = Math.max(0, Math.min(f, Math.floor((updates.length - 1) / 2)));
    const kept = updates.length - 2 * trim;
    for (let p = 0; p < result.length; p++) {
      const values: number[] = [];
      for (let i = 0; i < updates.length; i++) values.push(updates[i].delta[p]);
      values.sort((a: number, b: number) => a - b);
      let sum = 0;
      for (let i = trim; i < values.length - trim; i++) sum += values[i];
      result[p] = sum / kept;
    }
    return result;
  }

  // Krum selects the client update with the smallest distance to its nearest-neighbor set.
  static krum(updates: ClientUpdate[], byzantineCount: number): number[] {
    const n = updates.length;
    const neighborCount = Math.max(1, n - byzantineCount - 2);
    let bestIndex = 0;
    let bestScore = Number.POSITIVE_INFINITY;
    for (let i = 0; i < n; i++) {
      const distances: number[] = [];
      for (let j = 0; j < n; j++) {
        if (i === j) continue;
        let distance = 0;
        for (let p = 0; p < updates[i].delta.length; p++) {
          const difference = updates[i].delta[p] - updates[j].delta[p];
          distance += difference * difference;
        }
        distances.push(distance);
      }
      distances.sort((a: number, b: number) => a - b);
      let score = 0;
      for (let k = 0; k < Math.min(neighborCount, distances.length); k++) score += distances[k];
      if (score < bestScore) { bestScore = score; bestIndex = i; }
    }
    return updates[bestIndex].delta.slice();
  }
}

