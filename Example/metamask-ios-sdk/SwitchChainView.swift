//
//  SwitchChainView.swift
//  metamask-ios-sdk_Example
//

import SwiftUI
import Combine
import metamask_ios_sdk

@MainActor
struct SwitchChainView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var metamaskSDK: MetaMaskSDK

    @State private var alert: AlertInfo?
    @State var networkSelection: Network = .goerli

    struct AlertInfo: Identifiable {
        enum Status {
            case error
            case success
            case chainDoesNotExist
        }

        let id: Status
        let title: String
        let message: String

        var primaryButton: Alert.Button?
        var secondarButton: Alert.Button?
        var dismissButton: Alert.Button?
    }
    
    enum Network: String, CaseIterable, Identifiable {
        case goerli = "0x5"
        case kovan = "0x2a"
        case ethereum = "0x1"
        case polygon = "0x89"
        
        var id: Self { self }
        
        var chainId: String {
            rawValue
        }
        
        var name: String {
            switch self {
                case .polygon: return "Polygon"
                case .ethereum: return "Ethereum"
                case .kovan: return "Kovan Testnet"
                case .goerli: return "Goerli Testnet"
            }
        }
        
        var rpcUrls: [String] {
            switch self {
            case .polygon: return ["https://polygon-rpc.com"]
            default: return []
            }
        }
        
        static func chain(for chainId: String) -> String {
            self.allCases.first(where: { $0.rawValue == chainId })?.name ?? ""
        }
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Current chain:")
                        .modifier(TextCallout())
                    Spacer()
                    Text("\(Network.chain(for: metamaskSDK.chainId)) (\(metamaskSDK.chainId))")
                        .modifier(TextCalloutLight())
                }
                Picker("Switch to:", selection: $networkSelection) {
                    ForEach(Network.allCases) { network in
                        Text("\(network.name)")
                    }
                }
            }

            Section {
                Button {
                    Task {
                        await switchEthereumChain()
                    }
                } label: {
                    Text("Switch Chain ID")
                        .modifier(TextButton())
                        .frame(maxWidth: .infinity, maxHeight: 32)
                }
                .alert(item: $alert, content: { info in
                    if let _ = info.dismissButton {
                        return Alert(
                            title: Text(info.title),
                            message: Text(info.message),
                            dismissButton: info.dismissButton
                        )
                    } else {
                        return Alert(
                            title: Text(info.title),
                            message: Text(info.message),
                            primaryButton: info.primaryButton!,
                            secondaryButton: info.secondarButton!
                        )
                    }
                })
                .modifier(ButtonStyle())
            }
        }
        .onAppear {
            networkSelection = metamaskSDK.chainId == networkSelection.rawValue
                ? .ethereum
            : .goerli
        }
        .background(Color.blue.grayscale(0.5))
    }

    func switchEthereumChain() async {
        let switchChainParams: [String: String] = [
            "chainId": networkSelection.chainId
        ]

        let switchChainRequest = EthereumRequest(
            method: .switchEthereumChain,
            params: [switchChainParams] // wallet_switchEthereumChain rpc call expects an array parameters object
        )
        
        let switchChainResult = await metamaskSDK.request(switchChainRequest)
        
        switch switchChainResult {
        case .success(_):
            alert = AlertInfo(
                id: .success,
                title: "Success",
                message: "Successfully switched to \(networkSelection.name)",
                dismissButton: SwiftUI.Alert.Button.default(Text("OK"), action: {
                    presentationMode.wrappedValue.dismiss()
                })
            )
        case let .failure(error):
            if error.codeType == .unrecognizedChainId || error.codeType == .serverError {
                alert = AlertInfo(
                    id: .chainDoesNotExist,
                    title: "Error",
                    message: "\(networkSelection.name) (\(networkSelection.chainId)) has not been added to your MetaMask wallet. Add chain?",
                    primaryButton: SwiftUI.Alert.Button.default(Text("OK"), action: {
                        Task {
                            await addEthereumChain()
                        }
                    }),
                    secondarButton: SwiftUI.Alert.Button.default(Text("Cancel"))
                )
            } else {
                alert = AlertInfo(
                    id: .error,
                    title: "Error",
                    message: error.localizedDescription,
                    dismissButton: SwiftUI.Alert.Button.default(Text("OK"))
                )
            }
        }
    }

    func addEthereumChain() async {
        let addChainParams = AddChainRequest(
            chainId: networkSelection.chainId,
            chainName: networkSelection.name,
            rpcUrls: networkSelection.rpcUrls
        )

        let addChainRequest = EthereumRequest(
            method: .addEthereumChain,
            params: [addChainParams] // wallet_addEthereumChain rpc call expects an array parameters object
        )
        
        let addChainResult = await metamaskSDK.request(addChainRequest)
        
        switch addChainResult {
        case .success:
            alert = AlertInfo(
                id: .success,
                title: "Success",
                message: metamaskSDK.chainId == networkSelection.chainId
                    ? "Successfully switched to \(networkSelection.name)"
                    : "Successfully added \(networkSelection.name)",
                dismissButton: SwiftUI.Alert.Button.default(Text("OK"), action: {
                    presentationMode.wrappedValue.dismiss()
                })
            )
        case let .failure(error):
            alert = AlertInfo(
                id: .error,
                title: "Error",
                message: error.localizedDescription
            )
        }
    }
}

struct AddChainRequest: CodableData {
    let chainId: String
    let chainName: String
    let rpcUrls: [String]

    public func socketRepresentation() -> NetworkData {
        [
            "chainId": chainId,
            "chainName": chainName,
            "rpcUrls": rpcUrls
        ]
    }
}

struct SwitchChainView_Previews: PreviewProvider {
    static var previews: some View {
        SwitchChainView()
    }
}
