import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";
import { parseEther, ZeroAddress } from "ethers";

export default buildModule("AiPredictionV1Module", (m) => {

  const _ownerAddress = process.env.OWNER_ADDRESS;
  const _adminAddress = process.env.ADMIN_ADDRESS;

  const _oracleRouter = process.env.ORACLE_FUNCTIONS_ROUTER;
  const _oracleDonID = process.env.ORACLE_DON_ID;
  const _oracleSubscriptionId = process.env.ORACLE_SUBSCRIPTION_ID;

  const _oracleCallBackGasLimit = process?.env?.ORACLE_CALLBACK_GAS_LIMIT;
  const _minBetAmount = process?.env?.MIN_BET_AMOUNT;
  const _houseFee = process?.env?.HOUSE_FEE;
  const _roundMasterFee = process?.env?.ROUND_MASTER_FEE;



  if (!_ownerAddress || !_adminAddress || !_minBetAmount || !_houseFee || !_roundMasterFee || !_oracleRouter || !_oracleDonID || !_oracleCallBackGasLimit || !_oracleSubscriptionId) {
    throw new Error("Missing environment variables for AiPredictionV1Module");
  }

  if (_ownerAddress === ZeroAddress || _adminAddress === ZeroAddress || _oracleRouter === ZeroAddress) {
    throw new Error("Owner, Admin and router addresses cannot be zero address");
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
