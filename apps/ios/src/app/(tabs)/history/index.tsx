import { useAudioPlayer } from "expo-audio";
import { SymbolView } from "expo-symbols";
import { useMemo, useState } from "react";
import {
  Alert,
  Pressable,
  Share,
  StyleSheet,
  Text,
  TextInput,
  View,
} from "react-native";

import { AppScreen } from "@/components/app/app-screen";
import {
  type DictationHistoryItem,
  useHistory,
} from "@/features/history/history-store";

export default function HistoryScreen() {
  const history = useHistory();
  const [query, setQuery] = useState("");
  const [selectedID, setSelectedID] = useState<number | null>(
    history.items[0]?.id ?? null,
  );
  const filtered = useMemo(() => {
    const normalized = query.trim().toLocaleLowerCase();
    return normalized
      ? history.items.filter((item) =>
          item.text.toLocaleLowerCase().includes(normalized),
        )
      : history.items;
  }, [history.items, query]);
  const selected = history.items.find((item) => item.id === selectedID) ?? null;

  return (
    <AppScreen keyboardShouldPersistTaps="handled" scroll>
      <View style={styles.searchBox}>
        <SymbolView name="magnifyingglass" size={16} tintColor="#777f8e" />
        <TextInput
          onChangeText={setQuery}
          placeholder="Search history"
          placeholderTextColor="#717987"
          style={styles.searchInput}
          value={query}
        />
      </View>

      {filtered.length === 0 ? (
        <View style={styles.emptyState}>
          <SymbolView
            name="waveform.badge.magnifyingglass"
            size={42}
            tintColor="#59606d"
          />
          <Text style={styles.emptyTitle}>
            {query ? "No matches" : "No dictations yet"}
          </Text>
          <Text style={styles.emptyDetail}>
            Completed app and keyboard dictations are saved here.
          </Text>
        </View>
      ) : (
        filtered.map((item) => (
          <Pressable
            key={item.id}
            onPress={() => setSelectedID(item.id)}
            style={[
              styles.historyCard,
              selectedID === item.id && styles.selectedCard,
            ]}
          >
            <Text numberOfLines={3} style={styles.historyText}>
              {item.text}
            </Text>
            <View style={styles.metadataRow}>
              <Text style={styles.metadata}>{formatDate(item.createdAt)}</Text>
              <Text style={styles.metadata}>
                {formatDuration(item.durationMs)}
              </Text>
              <Text style={styles.sourceBadge}>
                {item.source === "keyboard" ? "KEYBOARD" : "APP"}
              </Text>
            </View>
          </Pressable>
        ))
      )}

      {selected ? (
        <HistoryDetail
          item={selected}
          onDelete={() => {
            void history.remove(selected);
            setSelectedID(null);
          }}
        />
      ) : null}
    </AppScreen>
  );
}

function HistoryDetail({
  item,
  onDelete,
}: {
  item: DictationHistoryItem;
  onDelete: () => void;
}) {
  const player = useAudioPlayer(item.audioUri);
  const confirmDelete = () =>
    Alert.alert(
      "Delete dictation?",
      "This removes the transcript and local recording.",
      [
        { style: "cancel", text: "Cancel" },
        { onPress: onDelete, style: "destructive", text: "Delete" },
      ],
    );

  return (
    <View style={styles.detailCard}>
      <Text style={styles.detailTitle}>Recording details</Text>
      <Text style={styles.detailText}>{item.text}</Text>
      <View style={styles.detailMetadata}>
        <Text style={styles.metadata}>Voxtral realtime</Text>
        <Text style={styles.metadata}>{formatDate(item.createdAt)}</Text>
      </View>
      <View style={styles.actionRow}>
        <ActionButton
          disabled={!item.audioUri}
          icon="play.fill"
          label="Play"
          onPress={() => player.play()}
        />
        <ActionButton
          icon="square.and.arrow.up"
          label="Share"
          onPress={() => Share.share({ message: item.text })}
        />
        <ActionButton
          destructive
          icon="trash"
          label="Delete"
          onPress={confirmDelete}
        />
      </View>
    </View>
  );
}

function ActionButton({
  destructive = false,
  disabled = false,
  icon,
  label,
  onPress,
}: {
  destructive?: boolean;
  disabled?: boolean;
  icon: string;
  label: string;
  onPress: () => void;
}) {
  return (
    <Pressable
      disabled={disabled}
      onPress={onPress}
      style={[styles.actionButton, disabled && styles.disabled]}
    >
      <SymbolView
        name={icon as never}
        size={17}
        tintColor={destructive ? "#ff656d" : "#9eb0ff"}
      />
      <Text style={[styles.actionLabel, destructive && styles.destructive]}>
        {label}
      </Text>
    </Pressable>
  );
}

function formatDate(value: string) {
  return new Date(value).toLocaleString(undefined, {
    dateStyle: "medium",
    timeStyle: "short",
  });
}

function formatDuration(durationMs: number) {
  const seconds = Math.max(1, Math.round(durationMs / 1_000));
  return seconds < 60
    ? `${seconds}s`
    : `${Math.floor(seconds / 60)}m ${seconds % 60}s`;
}

const styles = StyleSheet.create({
  searchBox: {
    height: 46,
    borderRadius: 15,
    backgroundColor: "#171a22",
    flexDirection: "row",
    alignItems: "center",
    gap: 10,
    paddingHorizontal: 14,
  },
  searchInput: { color: "#ffffff", fontSize: 16, flex: 1 },
  emptyState: { paddingVertical: 100, alignItems: "center", gap: 12 },
  emptyTitle: { color: "#cbd0da", fontSize: 20, fontWeight: "700" },
  emptyDetail: { color: "#717987", fontSize: 14, textAlign: "center" },
  historyCard: {
    borderRadius: 18,
    padding: 17,
    backgroundColor: "#151820",
    borderWidth: 1,
    borderColor: "#202531",
    gap: 12,
  },
  selectedCard: { borderColor: "#506fca" },
  historyText: { color: "#f2f4f8", fontSize: 17, lineHeight: 23 },
  metadataRow: { flexDirection: "row", alignItems: "center", gap: 10 },
  metadata: { color: "#737b89", fontSize: 12 },
  sourceBadge: {
    color: "#87a2ff",
    fontSize: 9,
    fontWeight: "800",
    letterSpacing: 0.8,
  },
  detailCard: {
    marginTop: 8,
    borderRadius: 20,
    padding: 20,
    backgroundColor: "#191c24",
    gap: 14,
  },
  detailTitle: { color: "#ffffff", fontSize: 20, fontWeight: "800" },
  detailText: { color: "#d9dde6", fontSize: 16, lineHeight: 23 },
  detailMetadata: { gap: 4 },
  actionRow: { flexDirection: "row", gap: 8 },
  actionButton: {
    flex: 1,
    minHeight: 48,
    borderRadius: 13,
    backgroundColor: "#252a37",
    alignItems: "center",
    justifyContent: "center",
    flexDirection: "row",
    gap: 7,
  },
  actionLabel: { color: "#acbaff", fontSize: 13, fontWeight: "700" },
  destructive: { color: "#ff757c" },
  disabled: { opacity: 0.35 },
});
