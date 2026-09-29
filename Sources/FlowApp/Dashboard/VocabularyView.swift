import FlowVocabulary
import SwiftUI

struct VocabularyView: View {
    @ObservedObject var store: VocabularyStore
    @State private var newTerm = ""
    @State private var newNote = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                PageHeader(
                    title: "Vocabulary",
                    subtitle: "Names and terms Flow should hear and spell correctly."
                )

                HStack(spacing: 8) {
                    field("Name or term", text: $newTerm)
                    field("Note (optional)", text: $newNote)
                    Button("Add", action: add)
                        .buttonStyle(SubtleButtonStyle(prominent: true))
                        .disabled(newTerm.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                if store.terms.isEmpty {
                    Text("Nothing here yet.")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(store.terms.enumerated()), id: \.element.id) { index, term in
                            if index > 0 { Rectangle().fill(Theme.hairline).frame(height: 1) }
                            HStack {
                                Text(term.term).font(.system(size: 13.5, weight: .medium))
                                if let note = term.note, !note.isEmpty {
                                    Text(note)
                                        .font(.system(size: 12))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button { store.remove(id: term.id) } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .semibold))
                                        .frame(width: 22, height: 22)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 11)
                        }
                    }
                }
            }
            .padding(.horizontal, Theme.pagePadding)
            .padding(.top, Theme.topInset)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func field(_ prompt: String, text: Binding<String>) -> some View {
        TextField(prompt, text: text)
            .textFieldStyle(.plain)
            .font(.system(size: 13))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            .onSubmit(add)
    }

    private func add() {
        let note = newNote.trimmingCharacters(in: .whitespaces)
        store.add(term: newTerm, note: note.isEmpty ? nil : note)
        newTerm = ""
        newNote = ""
    }
}
