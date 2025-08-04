'use client'

import React, { useState, useEffect } from 'react'
import { formatEther, parseEther } from 'viem'
import { useAccount, useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { ConnectButton } from '@rainbow-me/rainbowkit'
import { Wallet, ArrowDownToLine, ArrowUpFromLine, Coins, RefreshCw } from 'lucide-react'
import { CONTRACT_ADDRESSES, TOKEN_BANK_ABI, ERC20_ABI } from '@/lib/config'

export default function TokenBankInterface() {
  const { address, isConnected } = useAccount()
  const [depositAmount, setDepositAmount] = useState('')
  const [withdrawAmount, setWithdrawAmount] = useState('')
  const [isLoading, setIsLoading] = useState(false)

  // 读取用户的Token余额
  const { data: tokenBalance, refetch: refetchTokenBalance } = useReadContract({
    address: CONTRACT_ADDRESSES.BASE_ERC20 as `0x${string}`,
    abi: ERC20_ABI,
    functionName: 'balanceOf',
    args: address ? [address] : undefined,
  })

  // 读取用户在TokenBank中的存款余额
  const { data: bankBalance, refetch: refetchBankBalance } = useReadContract({
    address: CONTRACT_ADDRESSES.TOKEN_BANK as `0x${string}`,
    abi: TOKEN_BANK_ABI,
    functionName: 'balances',
    args: address ? [address] : undefined,
  })

  // 读取用户对TokenBank的授权额度
  const { data: allowance, refetch: refetchAllowance } = useReadContract({
    address: CONTRACT_ADDRESSES.BASE_ERC20 as `0x${string}`,
    abi: ERC20_ABI,
    functionName: 'allowance',
    args: address ? [address, CONTRACT_ADDRESSES.TOKEN_BANK] : undefined,
  })

  // 读取Token信息
  const { data: tokenName } = useReadContract({
    address: CONTRACT_ADDRESSES.BASE_ERC20 as `0x${string}`,
    abi: ERC20_ABI,
    functionName: 'name',
  })

  const { data: tokenSymbol } = useReadContract({
    address: CONTRACT_ADDRESSES.BASE_ERC20 as `0x${string}`,
    abi: ERC20_ABI,
    functionName: 'symbol',
  })

  // 写入合约的hooks
  const { writeContract: writeApprove, data: approveHash } = useWriteContract()
  const { writeContract: writeDeposit, data: depositHash } = useWriteContract()
  const { writeContract: writeWithdraw, data: withdrawHash } = useWriteContract()

  // 等待交易确认
  const { isLoading: isApproveLoading } = useWaitForTransactionReceipt({
    hash: approveHash,
  })
  const { isLoading: isDepositLoading } = useWaitForTransactionReceipt({
    hash: depositHash,
  })
  const { isLoading: isWithdrawLoading } = useWaitForTransactionReceipt({
    hash: withdrawHash,
  })

  // 刷新所有数据
  const refreshData = () => {
    refetchTokenBalance()
    refetchBankBalance()
    refetchAllowance()
  }

  // 授权Token
  const handleApprove = async () => {
    if (!depositAmount) return
    
    try {
      setIsLoading(true)
      await writeApprove({
        address: CONTRACT_ADDRESSES.BASE_ERC20 as `0x${string}`,
        abi: ERC20_ABI,
        functionName: 'approve',
        args: [CONTRACT_ADDRESSES.TOKEN_BANK, parseEther(depositAmount)],
      })
    } catch (error) {
      console.error('Approve failed:', error)
    } finally {
      setIsLoading(false)
    }
  }

  // 存款
  const handleDeposit = async () => {
    if (!depositAmount) return
    
    try {
      setIsLoading(true)
      await writeDeposit({
        address: CONTRACT_ADDRESSES.TOKEN_BANK as `0x${string}`,
        abi: TOKEN_BANK_ABI,
        functionName: 'deposit',
        args: [parseEther(depositAmount)],
      })
      setDepositAmount('')
    } catch (error) {
      console.error('Deposit failed:', error)
    } finally {
      setIsLoading(false)
    }
  }

  // 取款
  const handleWithdraw = async () => {
    if (!withdrawAmount) return
    
    try {
      setIsLoading(true)
      await writeWithdraw({
        address: CONTRACT_ADDRESSES.TOKEN_BANK as `0x${string}`,
        abi: TOKEN_BANK_ABI,
        functionName: 'withdraw',
        args: [parseEther(withdrawAmount)],
      })
      setWithdrawAmount('')
    } catch (error) {
      console.error('Withdraw failed:', error)
    } finally {
      setIsLoading(false)
    }
  }

  // 检查是否需要授权
  const needsApproval = allowance && depositAmount 
    ? BigInt(allowance.toString()) < parseEther(depositAmount)
    : true

  useEffect(() => {
    if (isConnected) {
      refreshData()
    }
  }, [isConnected])

  if (!isConnected) {
    return (
      <div className="min-h-screen gradient-bg flex items-center justify-center p-4">
        <div className="bg-white rounded-2xl card-shadow p-8 text-center max-w-md w-full">
          <Wallet className="w-16 h-16 mx-auto mb-4 text-blue-500" />
          <h1 className="text-2xl font-bold text-gray-800 mb-4">TokenBank DApp</h1>
          <p className="text-gray-600 mb-6">连接您的钱包开始使用TokenBank</p>
          <ConnectButton />
        </div>
      </div>
    )
  }

  return (
    <div className="min-h-screen gradient-bg p-4">
      <div className="max-w-4xl mx-auto">
        {/* Header */}
        <div className="bg-white rounded-2xl card-shadow p-6 mb-6">
          <div className="flex justify-between items-center">
            <div>
              <h1 className="text-3xl font-bold text-gray-800 flex items-center gap-2">
                <Coins className="w-8 h-8 text-blue-500" />
                TokenBank DApp
              </h1>
              <p className="text-gray-600 mt-1">管理您的 {tokenName || 'Token'} 存款</p>
            </div>
            <div className="flex items-center gap-4">
              <button
                onClick={refreshData}
                className="p-2 text-gray-500 hover:text-gray-700 transition-colors"
                title="刷新数据"
              >
                <RefreshCw className="w-5 h-5" />
              </button>
              <ConnectButton />
            </div>
          </div>
        </div>

        {/* Balance Cards */}
        <div className="grid md:grid-cols-2 gap-6 mb-6">
          <div className="bg-white rounded-2xl card-shadow p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-xl font-semibold text-gray-800">钱包余额</h2>
              <Wallet className="w-6 h-6 text-blue-500" />
            </div>
            <div className="text-3xl font-bold text-blue-600">
              {tokenBalance ? formatEther(tokenBalance) : '0'} {tokenSymbol || 'BERC20'}
            </div>
            <p className="text-gray-500 text-sm mt-1">可用于存款的代币数量</p>
          </div>

          <div className="bg-white rounded-2xl card-shadow p-6">
            <div className="flex items-center justify-between mb-4">
              <h2 className="text-xl font-semibold text-gray-800">银行存款</h2>
              <ArrowDownToLine className="w-6 h-6 text-green-500" />
            </div>
            <div className="text-3xl font-bold text-green-600">
              {bankBalance ? formatEther(bankBalance) : '0'} {tokenSymbol || 'BERC20'}
            </div>
            <p className="text-gray-500 text-sm mt-1">在TokenBank中的存款</p>
          </div>
        </div>

        {/* Operations */}
        <div className="grid md:grid-cols-2 gap-6">
          {/* Deposit */}
          <div className="bg-white rounded-2xl card-shadow p-6">
            <div className="flex items-center gap-2 mb-4">
              <ArrowDownToLine className="w-6 h-6 text-blue-500" />
              <h2 className="text-xl font-semibold text-gray-800">存款</h2>
            </div>
            
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  存款金额
                </label>
                <input
                  type="number"
                  value={depositAmount}
                  onChange={(e) => setDepositAmount(e.target.value)}
                  placeholder="输入存款金额"
                  className="input-field"
                  step="0.01"
                  min="0"
                />
              </div>

              {needsApproval && depositAmount ? (
                <button
                  onClick={handleApprove}
                  disabled={isLoading || isApproveLoading || !depositAmount}
                  className="button-primary w-full"
                >
                  {isApproveLoading ? '授权中...' : '授权Token'}
                </button>
              ) : (
                <button
                  onClick={handleDeposit}
                  disabled={isLoading || isDepositLoading || !depositAmount}
                  className="button-primary w-full"
                >
                  {isDepositLoading ? '存款中...' : '存款'}
                </button>
              )}
            </div>
          </div>

          {/* Withdraw */}
          <div className="bg-white rounded-2xl card-shadow p-6">
            <div className="flex items-center gap-2 mb-4">
              <ArrowUpFromLine className="w-6 h-6 text-red-500" />
              <h2 className="text-xl font-semibold text-gray-800">取款</h2>
            </div>
            
            <div className="space-y-4">
              <div>
                <label className="block text-sm font-medium text-gray-700 mb-2">
                  取款金额
                </label>
                <input
                  type="number"
                  value={withdrawAmount}
                  onChange={(e) => setWithdrawAmount(e.target.value)}
                  placeholder="输入取款金额"
                  className="input-field"
                  step="0.01"
                  min="0"
                  max={bankBalance ? formatEther(bankBalance) : '0'}
                />
              </div>

              <button
                onClick={handleWithdraw}
                disabled={isLoading || isWithdrawLoading || !withdrawAmount}
                className="button-primary w-full"
              >
                {isWithdrawLoading ? '取款中...' : '取款'}
              </button>
            </div>
          </div>
        </div>

        {/* Transaction Status */}
        {(isApproveLoading || isDepositLoading || isWithdrawLoading) && (
          <div className="bg-white rounded-2xl card-shadow p-6 mt-6">
            <div className="flex items-center gap-2 text-blue-600">
              <RefreshCw className="w-5 h-5 animate-spin" />
              <span>交易处理中，请稍候...</span>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}