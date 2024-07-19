// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract RateLimiter {
    error ValueTooBig(uint256 value);
    error LimitExceeded();
    error InvalidBinBytes();

    uint256 public immutable RATE_BIN_DURATION;
    uint256 public immutable RATE_BINS;
    uint256 public immutable RATE_BIN_BYTES;
    uint256 public immutable RATE_BIN_MAX_VALUE;
    uint256 public immutable RATE_BIN_MASK;
    uint256 public immutable RATE_BINS_PER_SLOT;

    mapping(uint256 => uint256) private _rateSlots;
    uint256 private _lastBinIdx;
    uint256 internal _limit;
    uint256 internal _rate;

    struct SlotCache {
        uint256 slotIdx;
        uint256 slotValue;
    }

    constructor(uint256 bins, uint256 binDuration, uint256 binBytes, uint256 limit) {
        RATE_BINS = bins;
        RATE_BIN_DURATION = binDuration;
        RATE_BIN_BYTES = binBytes;
        RATE_BIN_MAX_VALUE = (1 << (RATE_BIN_BYTES * 8)) - 1;
        RATE_BIN_MASK = RATE_BIN_MAX_VALUE;
        RATE_BINS_PER_SLOT = 32 / RATE_BIN_BYTES;
        if (RATE_BINS_PER_SLOT * RATE_BIN_BYTES != 32) revert InvalidBinBytes();
        _limit = limit;
    }

    function _getCache(uint256 binIdx) internal view returns (SlotCache memory) {
        uint256 slotIdx = (binIdx % RATE_BINS) / RATE_BINS_PER_SLOT;

        return SlotCache({slotIdx: slotIdx, slotValue: _rateSlots[slotIdx]});
    }

    function _commitCache(SlotCache memory cache) internal {
        _rateSlots[cache.slotIdx] = cache.slotValue;
    }

    function _flushIfEvicted(SlotCache memory cache, uint256 newSlotIdx) internal {
        if (newSlotIdx != cache.slotIdx) {
            _commitCache(cache);

            cache.slotIdx = newSlotIdx;
            cache.slotValue = _rateSlots[newSlotIdx];
        }
    }

    function _prepareBin(SlotCache memory cache, uint256 binIdx) internal returns (uint256 oldValue, uint256 off) {
        uint256 binIdxInWindow = binIdx % RATE_BINS;
        uint256 slotIdx = binIdxInWindow / RATE_BINS_PER_SLOT;
        _flushIfEvicted(cache, slotIdx);
        uint256 idxInSlot = binIdxInWindow % RATE_BINS_PER_SLOT;
        off = idxInSlot * RATE_BIN_BYTES * 8;
        oldValue = (cache.slotValue >> off) & RATE_BIN_MASK;
    }

    function _setBinValue(SlotCache memory cache, uint256 binIdx, uint256 value) internal returns (uint256) {
        if (value > RATE_BIN_MAX_VALUE) {
            revert ValueTooBig({value: value});
        }
        (uint256 oldValue, uint256 off) = _prepareBin(cache, binIdx);
        cache.slotValue = (cache.slotValue & (~(RATE_BIN_MASK << off))) | (value << off);
        return oldValue;
    }

    function _addBinValue(SlotCache memory cache, uint256 binIdx, uint256 value) internal returns (uint256) {
        (uint256 oldValue, uint256 off) = _prepareBin(cache, binIdx);
        uint256 newValue = oldValue + value;
        if (newValue > RATE_BIN_MAX_VALUE) {
            revert ValueTooBig({value: newValue});
        }
        cache.slotValue = (cache.slotValue & (~(RATE_BIN_MASK << off))) | (newValue << off);
        return oldValue;
    }

    function _resetRate() internal {
        for (uint256 i = 0; i < (RATE_BINS + RATE_BINS_PER_SLOT - 1) / RATE_BINS_PER_SLOT; i++) {
            _rateSlots[i] = 0;
        }
        _rate = 0;
    }

    function _checkRateLimit(uint256 amount) internal {
        uint256 binIdx = block.timestamp / RATE_BIN_DURATION;

        if (binIdx - _lastBinIdx >= RATE_BINS) {
            _resetRate();
            _lastBinIdx = binIdx;
        }

        SlotCache memory cache = _getCache(_lastBinIdx);
        uint256 rate = _rate;

        if (binIdx != _lastBinIdx) {
            for (uint256 idx = _lastBinIdx + 1; idx <= binIdx; idx++) {
                uint256 oldValue = _setBinValue(cache, idx, 0);
                rate -= oldValue;
            }
            _lastBinIdx = binIdx;
        }

        rate += amount;
        if (rate > _limit) {
            revert LimitExceeded();
        }
        _rate = rate;
        _addBinValue(cache, binIdx, amount);
        _commitCache(cache);
    }
}
