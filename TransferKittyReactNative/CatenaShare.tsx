import React, { useState, useEffect, useCallback } from 'react';
import { Modal, NativeModules, Alert, StyleSheet, SafeAreaView, View, BackHandler } from 'react-native';
import RNExitApp from 'react-native-exit-app';

import ShareHeader from './components/share-header';
import DeviceList from './components/device-list';
import ShareContent from './components/share-content';

NativeModules.DevSettings.setIsDebuggingRemotely(true)

export default function CatenaShare() {
  const [selected, setSelected] = useState();
  const [visible, setVisible] = useState(true);

  const closeApp = useCallback(() => {
    setVisible(false);
    NativeModules.ShareViewController.close();
  }, []);

  return (
    <View>
      <Modal animationType="slide" transparent={false} visible={visible} onRequestClose={() => setVisible(false)} presentationStyle="pageSheet">
        <View style={styles.container}>
          <ShareHeader onClose={closeApp} />
          <DeviceList onSelect={setSelected} selected={selected} />
          <ShareContent selected={selected} />
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    marginTop: 5,
    flex: 1,
  },
  contentWrapper: {
    flex: 1,
    backgroundColor: '#fff',
    // opacity: 0.95,
  }
});
