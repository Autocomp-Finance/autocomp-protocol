// SPDX-License-Identifier: MIT

pragma solidity ^0.8.4;

contract AutocompPriceMulticall {
  function getUint(address addr, bytes memory data)
    internal
    view
    returns (uint256 result)
  {
    result = 0;

    (bool status, bytes memory res) = addr.staticcall(data);

    if (status && res.length >= 32) {
      assembly {
        result := mload(add(add(res, 0x20), 0))
      }
    }
  }

  function getLpInfo(address[][] calldata pools)
    external
    view
    returns (uint256[] memory)
  {
    uint256[] memory results = new uint256[](pools.length * 3);
    uint256 idx = 0;

    for (uint256 i = 0; i < pools.length; i++) {
      address lp = pools[i][0];
      address t0 = pools[i][1];
      address t1 = pools[i][2];

      results[idx++] = getUint(lp, abi.encodeWithSignature("totalSupply()"));
      results[idx++] = getUint(
        t0,
        abi.encodeWithSignature("balanceOf(address)", lp)
      );
      results[idx++] = getUint(
        t1,
        abi.encodeWithSignature("balanceOf(address)", lp)
      );
    }

    return results;
  }
}
