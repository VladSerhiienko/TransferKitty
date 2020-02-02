import React from 'react';
import { UIManager, SafeAreaView, Animated, StyleSheet, Text, View, Button, TabBarIOS } from 'react-native';

import ShareHeader from './components/share-header';
import DeviceList from './components/device-list';
import ShareContent from './components/share-content';

// UIManager.setLayoutAnimationEnabledExperimental(true);

export default function CatenaShare() {
  return (
    // <SafeAreaView>
      <View style={styles.container}>
        <View style={styles.contentWrapper}>
          <ShareHeader />
          <DeviceList />
          {/* <ShareContent  /> */}
        </View>
      </View>
    // </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'stretch',
  },
  contentWrapper: {
    flex: 1,
    backgroundColor: '#fff',
    opacity: 0.95,
  }
});
