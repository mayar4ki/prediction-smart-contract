// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

abstract contract AdminACL is Ownable, Pausable {
    address public _admin; // address of the admin

    constructor(address _ownerAddress, address _adminAddress) Ownable(_ownerAddress) {
        _admin = _adminAddress;
    }

    event Pause();
    event Unpause();
    event NewAdminAddress(address admin);

    modifier onlyAdmin() {
        require(msg.sender == _admin, "Not admin");
        _;
    }

    /**
     * @notice Set admin address
     */
    function setAdmin(address _adminAddress) external onlyOwner {
        require(_adminAddress != address(0), "Cannot be zero address");
        _admin = _adminAddress;

        emit NewAdminAddress(_adminAddress);
    }

    /**
     * @notice called by the admin to unpause, returns to normal state
     */
    function unpause() external whenPaused onlyAdmin {
        _unpause();
        emit Unpause();
    }

    /**
     * @notice called by the admin to pause, triggers stopped state
     */
    function pause() external whenNotPaused onlyAdmin {
        _pause();
        emit Pause();
    }
}
