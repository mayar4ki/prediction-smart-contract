import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { parseEther, zeroAddress } from 'viem';

export interface NetworkConfig {
  MIN_BET_AMOUNT: string;             // Default: 0.01 ETH
  HOUSE_FEE: string;                  // Default: 100 (1%)
  ROUND_MASTER_FEE: string;          // Default: 200 (2%)
  ORACLE_CALLBACK_GAS_LIMIT: string; // Default: 300000
}

export const config: NetworkConfig = {
  MIN_BET_AMOUNT: '0.01',
  HOUSE_FEE: '100',
  ROUND_MASTER_FEE: '200',
  ORACLE_CALLBACK_GAS_LIMIT: '300000',
};

export default buildModule("AiPredictionV1Module", (m) => {

  const _ownerAddress = process.env.OWNER_ADDRESS;
  const _adminAddress = process.env.ADMIN_ADDRESS;

  const _oracleRouter = process.env.ORACLE_ROUTER;
  const _oracleDonID = process.env.ORACLE_DON_ID;
  const _oracleSubscriptionId = process.env.ORACLE_SUBSCRIPTION_ID;

  const _oracleCallBackGasLimit = process?.env?.ORACLE_CALLBACK_GAS_LIMIT ?? config.ORACLE_CALLBACK_GAS_LIMIT;
  const _minBetAmount = process?.env?.MIN_BET_AMOUNT ?? config.MIN_BET_AMOUNT;
  const _houseFee = process?.env?.HOUSE_FEE ?? config.HOUSE_FEE;
  const _roundMasterFee = process?.env?.ROUND_MASTER_FEE ?? config.ROUND_MASTER_FEE;



  if (!_ownerAddress || !_adminAddress || !_minBetAmount || !_houseFee || !_roundMasterFee || !_oracleRouter || !_oracleDonID || !_oracleCallBackGasLimit || !_oracleSubscriptionId) {
    throw new Error("Missing environment variables for AiPredictionV1Module");
  }

  if (_ownerAddress === zeroAddress || _adminAddress === zeroAddress) {
    throw new Error("Owner and Admin addresses cannot be zero address");
  }

  const aiPredictionV1 = m.contract("AiPredictionV1", [
    m.getParameter("_ownerAddress", _ownerAddress),
    m.getParameter("_adminAddress", _adminAddress),
    m.getParameter("_minBetAmount", parseEther(_minBetAmount)),
    m.getParameter("_houseFee", _houseFee),
    m.getParameter("_roundMasterFee", _roundMasterFee),
    m.getParameter("_oracleRouter", _oracleRouter),
    m.getParameter("_oracleDonID", _oracleDonID),
    m.getParameter("_oracleCallBackGasLimit", _oracleCallBackGasLimit),
    m.getParameter("_oracleSubscriptionId", _oracleSubscriptionId),
  ]);

  return { aiPredictionV1 };
});
