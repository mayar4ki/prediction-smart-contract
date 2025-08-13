// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.2 <0.9.0;

library MyEnums  {


 
    enum BetOptions {
        Yes,
        No
    }
    
    enum OracleCallStatus {
        SUCCESS,
        PENDING,
        ERROR
    }

    struct Stats {
        uint sum;
        uint count;
    }


 
}
