import './globals.css'
import { Providers } from '@/components/Providers'

export const metadata = {
  title: 'TokenBank DApp',
  description: '基于Viem的TokenBank去中心化应用',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="zh">
      <body>
        <Providers>
          {children}
        </Providers>
      </body>
    </html>
  )
}