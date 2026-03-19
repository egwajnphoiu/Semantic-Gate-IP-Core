/**
 * @file engine.js
 * @author Jonathan Alan Reed
 * @description Production-grade Semantic Gate Logic Engine.
 * Directly mirrors the SystemVerilog semantic_gate_core logic.
 * Implements Manhattan Distance accumulation and Self-Calibration.
 * @license AGPL 3.0
 */

class SemanticGateEngine {
    /**
     * @param {number} vectorDim - The dimensionality of the vectors (e.g., 1536).
     * @param {number} marginDivisor - Sensitivity control (Default 5 = 20% margin).
     */
    constructor(vectorDim = 1536, marginDivisor = 5) {
        this.VECTOR_DIM = vectorDim;
        this.MARGIN_DIVISOR = marginDivisor;
        this.WARMUP_CYCLES = 5;
        this.CAL_SAMPLES = 10;

        this.cycleCount = 0;
        this.calSum = 0;
        this.dynamicThreshold = Infinity;
        this.calibrated = false;
    }

    /**
     * Processes a single set of semantic vectors.
     * @param {Array<number>} anchor - The context vector.
     * @param {Array<number>} relation - The logic/intent vector.
     * @param {Array<number>} actual - The real-time output vector.
     * @returns {Object} Diagnostic results of the cycle.
     */
    processVectorSet(anchor, relation, actual) {
        let errorEnergy = 0;

        // Core Mathematical Manifold Check
        for (let i = 0; i < this.VECTOR_DIM; i++) {
            const prediction = anchor[i] + relation[i];
            errorEnergy += Math.abs(prediction - actual[i]);
        }

        let faultDetected = false;

        // Deterministic State Machine
        if (this.cycleCount < this.WARMUP_CYCLES) {
            this.cycleCount++;
        } 
        else if (this.cycleCount < (this.WARMUP_CYCLES + this.CAL_SAMPLES)) {
            this.calSum += errorEnergy;
            this.cycleCount++;
        } 
        else if (this.cycleCount === (this.WARMUP_CYCLES + this.CAL_SAMPLES)) {
            const averageEnergy = this.calSum / this.CAL_SAMPLES;
            // Lock threshold: Average + (Average / MarginDivisor)
            this.dynamicThreshold = averageEnergy + (averageEnergy / this.MARGIN_DIVISOR);
            this.calibrated = true;
            this.cycleCount++;
        } 
        else {
            // Active Inference Protection
            if (errorEnergy > this.dynamicThreshold) {
                faultDetected = true;
            }
        }

        return {
            energy: errorEnergy,
            threshold: this.dynamicThreshold,
            calibrated: this.calibrated,
            fault: faultDetected,
            cycle: this.cycleCount
        };
    }
}